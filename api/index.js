
const express = require('express');

const cors = require('cors');
const admin = require('firebase-admin');
const fs = require('fs');
const { v4: uuidv4 } = require('uuid');

if (admin.apps.length === 0) {
  try {
    if (fs.existsSync('/etc/secrets/firebase-sa.json')) {
      const serviceAccount = JSON.parse(fs.readFileSync('/etc/secrets/firebase-sa.json', 'utf8'));
      admin.initializeApp({
        credential: admin.credential.cert(serviceAccount),
      });
    } else if (process.env.GOOGLE_SERVICE_ACCOUNT) {
      const serviceAccount = JSON.parse(process.env.GOOGLE_SERVICE_ACCOUNT);
      admin.initializeApp({
        credential: admin.credential.cert(serviceAccount),
      });
    } else {
      admin.initializeApp();
    }
  } catch (e) {
    console.error('Firebase init error:', e);
    admin.initializeApp();
  }
}

const db = admin.firestore();
const auth = admin.auth();
const messaging = admin.messaging();

const app = express();
app.use(cors({ origin: true }));
app.use(express.json());

async function verifyAuth(req, res, next) {
  try {
    const header = req.headers.authorization || '';
    const token = header.startsWith('Bearer ') ? header.slice(7) : null;
    if (!token) return res.status(401).json({ error: 'unauthenticated' });
    const decoded = await auth.verifyIdToken(token);
    req.uid = decoded.uid;
    next();
  } catch (e) {
    return res.status(401).json({ error: 'unauthenticated' });
  }
}

function badRequest(res, msg) { return res.status(400).json({ error: msg }); }

app.get('/health', (req, res) => res.json({ ok: true }));

app.post('/createReservation', verifyAuth, async (req, res) => {
  try {
    const uid = req.uid;
    const { productId, quantity, fulfillmentType, scheduledForIso, deliveryAddressText, notes } = req.body || {};
    
    if (!productId) return badRequest(res, 'Missing productId.');
    if (!Number.isInteger(quantity) || quantity <= 0) return badRequest(res, 'Quantity must be a positive whole number.');
    if (fulfillmentType !== 'pickup' && fulfillmentType !== 'delivery') return badRequest(res, 'Invalid fulfillment type.');
    if (fulfillmentType === 'delivery' && !deliveryAddressText) return badRequest(res, 'Delivery address is required.');
    const scheduledFor = new Date(scheduledForIso);
    if (isNaN(scheduledFor.getTime()) || scheduledFor.getTime() < Date.now()) {
      return badRequest(res, 'Reservation date/time must be in the future.');
    }

    const consumerSnap = await db.collection('users').doc(uid).get();
    if (!consumerSnap.exists) return badRequest(res, 'Consumer profile not found.');
    const consumer = consumerSnap.data();
    if (consumer.role !== 'consumer') return badRequest(res, 'Only consumer accounts can make reservations.');
    if (consumer.status !== 'active') return badRequest(res, 'Your account is not active.');

    const reservationId = await db.runTransaction(async (tx) => {
      const productRef = db.collection('products').doc(productId);
      const productSnap = await tx.get(productRef);
      if (!productSnap.exists) throw new Error('Product not found.');
      const product = productSnap.data();
      if (product.status !== 'active') throw new Error(`${product.name} is not available for reservation.`);

      const storeId = product.storeId || product.merchantId;
      if (!storeId) throw new Error('Store not found.');
      const storeRef = db.collection('stores').doc(storeId);
      const storeSnap = await tx.get(storeRef);
      let store;
      if (!storeSnap.exists) {
        const userSnap = await tx.get(db.collection('users').doc(storeId));
        const userData = userSnap.exists ? userSnap.data() : {};
        store = {
          name: userData.storeName || userData.fullName || userData.businessName || 'Store',
          merchantId: storeId,
          verificationStatus: 'active',
          isOpen: true,
          reservationExpirationMinutes: 120,
        };
      } else {
        store = storeSnap.data();
      }
      if (store.verificationStatus !== 'active') throw new Error(`${store.name} is not currently available.`);
      if (store.isOpen === false) throw new Error(`${store.name} is currently closed.`);

      const current = product.currentStock || 0;
      const reserved = product.reservedStock || 0;
      const available = current - reserved;
      if (quantity > available) {
        throw new Error(`Only ${available} ${product.unit || 'pc'} of ${product.name} available to reserve.`);
      }

      const expirationMinutes = store.reservationExpirationMinutes || 120;
      const expiresAt = admin.firestore.Timestamp.fromMillis(Date.now() + expirationMinutes * 60 * 1000);

      const reservationRef = db.collection('reservations').doc();
      tx.update(productRef, { reservedStock: reserved + quantity, updatedAt: admin.firestore.FieldValue.serverTimestamp() });

      const movementRef = db.collection('inventory_movements').doc();
      tx.set(movementRef, {
        productId,
        storeId: storeId,
        type: 'reservation',
        quantityBefore: reserved,
        quantityChanged: quantity,
        quantityAfter: reserved + quantity,
        reason: 'Product reserved by consumer',
        relatedOrderId: null,
        relatedReservationId: reservationRef.id,
        relatedDeliveryId: null,
        performedByUserId: uid,
        performedByName: consumer.fullName || 'Consumer',
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      tx.set(reservationRef, {
        consumerId: uid,
        consumerName: consumer.fullName || '',
        storeId: storeId,
        storeName: store.name,
        merchantId: store.merchantId || product.merchantId || storeId,
        productId,
        productName: product.name,
        productImageUrl: (product.imageUrls && product.imageUrls[0]) || product.imageUrl || null,
        quantity,
        unitPrice: product.sellingPrice || product.price || 0,
        fulfillmentType,
        scheduledFor: admin.firestore.Timestamp.fromDate(scheduledFor),
        status: 'pending',
        rejectionReason: null,
        expiresAt,
        reminderSent: false,
        deliveryAddressText: deliveryAddressText || null,
        notes: notes || null,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      return reservationRef.id;
    });

    try {
      const productSnap2 = await db.collection('products').doc(productId).get();
      const product2 = productSnap2.data();
      if (product2) {
        const merchantId2 = product2.merchantId || product2.storeId;
        await db.collection('notifications').add({
          userId: merchantId2,
          type: 'reservationRequest',
          title: 'New reservation request',
          message: `${consumer.fullName || 'A consumer'} wants to reserve ${quantity} ${product2.unit || 'pc'} of ${product2.name}.`,
          relatedRecordId: reservationId,
          relatedRecordType: 'reservation',
          read: false,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {}

    res.json({ reservationId });
  } catch (e) {
    res.status(400).json({ error: e.message || 'Could not create reservation.' });
  }
});

app.post('/processCheckout', verifyAuth, async (req, res) => {
  try {
    const uid = req.uid;
    const { idempotencyKey, groups } = req.body || {};
    if (!idempotencyKey || typeof idempotencyKey !== 'string') return badRequest(res, 'Missing idempotencyKey.');
    if (!Array.isArray(groups) || groups.length === 0) return badRequest(res, 'Cart is empty.');
    
    const attemptRef = db.collection('checkout_attempts').doc(idempotencyKey);
    const existing = await attemptRef.get();
    if (existing.exists) {
      return res.json(existing.data());
    }

    const consumerSnap = await db.collection('users').doc(uid).get();
    if (!consumerSnap.exists) return badRequest(res, 'Consumer profile not found.');
    const consumer = consumerSnap.data();
    if (consumer.role !== 'consumer') return badRequest(res, 'Only consumer accounts can check out.');
    if (consumer.status !== 'active') return badRequest(res, 'Your account is not active.');

    const settingsSnap = await db.collection('app_settings').doc('default').get();
    const settings = settingsSnap.exists ? settingsSnap.data() : { defaultDeliveryFee: 0, platformFeePercent: 5 };

    const checkoutGroupId = idempotencyKey;
    const orderIds = [];

    for (const group of groups) {
      const orderId = await db.runTransaction(async (tx) => {
        const storeRef = db.collection('stores').doc(group.storeId);
        const storeSnap = await tx.get(storeRef);
        let store;
        if (!storeSnap.exists) {
          const userSnap = await tx.get(db.collection('users').doc(group.storeId));
          const userData = userSnap.exists ? userSnap.data() : {};
          store = {
            name: userData.storeName || userData.fullName || userData.businessName || 'Store',
            merchantId: group.storeId,
            verificationStatus: 'active',
            isOpen: true,
            reservationExpirationMinutes: 120,
          };
        } else {
          store = storeSnap.data();
        }
        if (store.verificationStatus !== 'active') throw new Error(`${store.name} is not currently available.`);
        if (store.isOpen === false) throw new Error(`${store.name} is currently closed.`);

        let subtotal = 0;
        let cogs = 0;
        const orderItems = [];
        const productUpdates = [];

        for (let i = 0; i < group.items.length; i++) {
          const item = group.items[i];
          const productRef = db.collection('products').doc(item.productId);
          const productSnap = await tx.get(productRef);
          if (!productSnap.exists) throw new Error('A product in your cart is no longer available.');
          const product = productSnap.data();
          if (product.storeId !== group.storeId && product.merchantId !== group.storeId) throw new Error('Product does not belong to this store.');
          if (product.status !== 'active') throw new Error(`${product.name} is no longer available.`);

          const current = product.currentStock || 0;
          const reserved = product.reservedStock || 0;
          const available = current - reserved;
          if (item.quantity > available) throw new Error(`Only ${available} ${product.unit || 'pc'} of ${product.name} left in stock.`);

          const unitPrice = product.sellingPrice || product.price || 0;
          subtotal += unitPrice * item.quantity;
          cogs += (product.costPrice || 0) * item.quantity;
          orderItems.push({
            productId: item.productId,
            productName: product.name,
            productImageUrl: (product.imageUrls && product.imageUrls[0]) || product.imageUrl || null,
            unitPrice,
            quantity: item.quantity,
            unit: product.unit || 'pc',
            subtotal: Math.round(unitPrice * item.quantity * 100) / 100,
          });

          const isCod = group.paymentMethod === 'cashOnDelivery';
          productUpdates.push({
            ref: productRef,
            afterStock: isCod ? current - item.quantity : current,
            afterReserved: isCod ? reserved : reserved + item.quantity,
            reservedBefore: reserved,
            before: current,
          });
        }

        const deliveryFee = group.fulfillmentType === 'delivery' ? (settings.defaultDeliveryFee || 0) : 0;
        const platformFee = Math.round(subtotal * ((settings.platformFeePercent || 5) / 100) * 100) / 100;
        const total = Math.round((subtotal + deliveryFee + platformFee) * 100) / 100;
        const orderRef = db.collection('orders').doc();
        const isCod = group.paymentMethod === 'cashOnDelivery';

        for (let i = 0; i < productUpdates.length; i++) {
          const pu = productUpdates[i];
          tx.update(pu.ref, { currentStock: pu.afterStock, reservedStock: pu.afterReserved, updatedAt: admin.firestore.FieldValue.serverTimestamp() });
          const movementRef = db.collection('inventory_movements').doc();
          tx.set(movementRef, {
            productId: group.items[i].productId,
            storeId: group.storeId,
            type: isCod ? 'sale' : 'reservation',
            quantityBefore: isCod ? pu.before : pu.reservedBefore,
            quantityChanged: isCod ? -group.items[i].quantity : group.items[i].quantity,
            quantityAfter: isCod ? pu.afterStock : pu.afterReserved,
            reason: isCod ? 'Cash on delivery order confirmed' : 'Stock held for pending-payment order',
            relatedOrderId: orderRef.id,
            relatedReservationId: null,
            relatedDeliveryId: null,
            performedByUserId: uid,
            performedByName: consumer.fullName || 'Consumer',
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
          });
        }

        const orderData = {
          checkoutGroupId,
          consumerId: uid,
          consumerName: consumer.fullName || '',
          storeId: group.storeId,
          storeName: store.name,
          merchantId: store.merchantId,
          items: orderItems,
          subtotal: Math.round(subtotal * 100) / 100,
          deliveryFee,
          discount: 0,
          platformFee,
          total,
          paymentMethod: group.paymentMethod,
          status: isCod ? 'confirmed' : 'pendingPayment',
          fulfillmentType: group.fulfillmentType,
          deliveryAddressId: group.deliveryAddressId || null,
          deliveryAddressText: group.deliveryAddressText || null,
          notes: group.notes || null,
          cancellationReason: null,
          reviewed: false,
        };
        tx.set(orderRef, { ...orderData, createdAt: admin.firestore.FieldValue.serverTimestamp(), updatedAt: admin.firestore.FieldValue.serverTimestamp() });

        if (isCod) {
          const receiptRef = db.collection('digital_receipts').doc(orderRef.id);
          const receiptNumber = `SLW-${new Date().getFullYear()}-${orderRef.id.slice(0, 8).toUpperCase()}`;
          tx.set(receiptRef, {
            receiptNumber,
            orderId: orderRef.id,
            storeName: store.name || group.storeId,
            storePhone: store.phone || '',
            storeEmail: store.email || '',
            consumerName: orderData.consumerName,
            items: orderItems,
            subtotal: orderData.subtotal,
            deliveryFee,
            discount: 0,
            platformFee,
            total,
            paymentMethod: group.paymentMethod,
            paymentStatus: 'successful',
            orderStatus: 'confirmed',
            transactionReference: orderRef.id,
            issuedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
        }

        const paymentRef = db.collection('payments').doc(orderRef.id);
        tx.set(paymentRef, {
          orderId: orderRef.id,
          checkoutGroupId,
          consumerId: uid,
          merchantId: store.merchantId,
          method: group.paymentMethod,
          status: isCod ? 'successful' : 'pending',
          amount: total,
          idempotencyKey: `${idempotencyKey}:${orderRef.id}`,
          providerReference: null,
          failureReason: null,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        return orderRef.id;
      });
      orderIds.push(orderId);
    }

    try {
      const cartItemsRef = db.collection('carts').doc(uid).collection('items');
      const batch = db.batch();
      for (const group of groups) {
        for (const item of group.items) {
          batch.delete(cartItemsRef.doc(item.productId));
        }
      }
      await batch.commit();
    } catch (e) {}

    const result = { checkoutGroupId, orderIds };
    await attemptRef.set({ ...result, uid, createdAt: admin.firestore.FieldValue.serverTimestamp() });

    res.json(result);
  } catch (e) {
    res.status(400).json({ error: e.message || 'Checkout failed.' });
  }
});

app.post('/syncStore', verifyAuth, async (req, res) => {
  try {
    const uid = req.uid;
    const userSnap = await db.collection('users').doc(uid).get();
    if (!userSnap.exists) return badRequest(res, 'User not found.');
    const user = userSnap.data();
    if (user.role !== 'merchant' && user.role !== 'supplier') return badRequest(res, 'Not a merchant/supplier account.');
    const collection = user.role === 'supplier' ? 'suppliers' : 'stores';
    const field = user.role === 'supplier' ? 'userId' : 'merchantId';
    const newStatus = user.status === 'active' ? 'active' : 'pendingVerification';
    const isSupplier = user.role === 'supplier';

    // Collect all store/supplier docs for this merchant (by doc id or by field).
    const refs = new Set();
    const byId = await db.collection(collection).doc(uid).get();
    if (byId.exists) refs.add(byId.ref);
    const byField = await db.collection(collection).where(field, '==', uid).get();
    byField.docs.forEach((d) => refs.add(d.ref));

    if (refs.size === 0) {
      const ref = db.collection(collection).doc(uid);
      if (isSupplier) {
        await ref.set({
          userId: uid,
          companyName: user.fullName || 'My Company',
          contactName: user.fullName || '',
          phone: user.phone || '',
          email: user.email || '',
          address: '',
          suppliedCategories: [],
          verificationStatus: newStatus,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      } else {
        await ref.set({
          merchantId: uid,
          name: 'My Store',
          description: '',
          category: 'General',
          phone: user.phone || '',
          email: user.email || '',
          addressLine: '',
          city: '',
          verificationStatus: newStatus,
          barcodeEnabled: false,
          reservationExpirationMinutes: 120,
          averageRating: 0,
          ratingCount: 0,
          planTier: 'free',
          isOpen: true,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }
    } else {
      const batch = db.batch();
      refs.forEach((r) => {
        batch.update(r, { verificationStatus: newStatus, updatedAt: admin.firestore.FieldValue.serverTimestamp() });
      });
      await batch.commit();
    }
    res.json({ ok: true, status: newStatus });
  } catch (e) {
    res.status(400).json({ error: e.message || 'Sync failed.' });
  }
});

app.post('/syncAllStores', verifyAuth, async (req, res) => {
  try {
    const adminSnap = await db.collection('users').doc(req.uid).get();
    if (!adminSnap.exists || adminSnap.data().role !== 'admin') return res.status(403).json({ error: 'forbidden' });
    const usersSnap = await db.collection('users').where('role', 'in', ['merchant', 'supplier']).get();
    let synced = 0;
    for (const userDoc of usersSnap.docs) {
      const user = userDoc.data();
      const uid = userDoc.id;
      const isSupplier = user.role === 'supplier';
      const collection = isSupplier ? 'suppliers' : 'stores';
      const field = isSupplier ? 'userId' : 'merchantId';
      const newStatus = user.status === 'active' ? 'active' : 'pendingVerification';

      const refs = new Set();
      const byId = await db.collection(collection).doc(uid).get();
      if (byId.exists) refs.add(byId.ref);
      const byField = await db.collection(collection).where(field, '==', uid).get();
      byField.docs.forEach((d) => refs.add(d.ref));

      if (refs.size === 0) {
        const ref = db.collection(collection).doc(uid);
        if (isSupplier) {
          await ref.set({
            userId: uid,
            companyName: user.fullName || 'My Company',
            contactName: user.fullName || '',
            phone: user.phone || '',
            email: user.email || '',
            address: '',
            suppliedCategories: [],
            verificationStatus: newStatus,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
        } else {
          await ref.set({
            merchantId: uid,
            name: 'My Store',
            description: '',
            category: 'General',
            phone: user.phone || '',
            email: user.email || '',
            addressLine: '',
            city: '',
            verificationStatus: newStatus,
            barcodeEnabled: false,
            reservationExpirationMinutes: 120,
            averageRating: 0,
            ratingCount: 0,
            planTier: 'free',
            isOpen: true,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
        }
      } else {
        const batch = db.batch();
        refs.forEach((r) => {
          batch.update(r, { verificationStatus: newStatus, updatedAt: admin.firestore.FieldValue.serverTimestamp() });
        });
        await batch.commit();
      }
      synced++;
    }
    res.json({ ok: true, synced });
  } catch (e) {
    res.status(400).json({ error: e.message || 'Sync failed.' });
  }
});

app.post('/verifyAccount', verifyAuth, async (req, res) => {
  try {
    const uid = req.uid;
    const adminSnap = await db.collection('users').doc(uid).get();
    if (!adminSnap.exists || adminSnap.data().role !== 'admin') return res.status(403).json({ error: 'forbidden' });
    const { targetUserId, targetType, decision, reason } = req.body || {};
    if (!targetUserId || !targetType || !decision) return badRequest(res, 'Missing required fields.');
    if (decision === 'reject' && (!reason || !reason.trim())) return badRequest(res, 'A reason is required to reject an account.');

    const targetRef = db.collection('users').doc(targetUserId);
    const targetSnap = await targetRef.get();
    if (!targetSnap.exists) return badRequest(res, 'Account not found.');
    if (targetSnap.data().role !== targetType) return badRequest(res, 'Account role mismatch.');

    const newStatus = decision === 'approve' ? 'active' : 'rejected';
    const collection = targetType === 'merchant' ? 'stores' : 'suppliers';
    const profileRef = db.collection(collection).doc(targetUserId);
    const profileSnap = await profileRef.get();

    await targetRef.update({
      status: newStatus,
      statusReason: decision === 'reject' ? reason.trim() : null,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    if (profileSnap.exists) {
      await profileRef.update({
        verificationStatus: newStatus,
        verificationNote: decision === 'reject' ? reason.trim() : null,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    } else {
      // create profile if missing
      if (targetType === 'merchant') {
        await profileRef.set({
          merchantId: targetUserId,
          name: 'My Store',
          description: '',
          category: 'General',
          phone: '',
          email: '',
          addressLine: '',
          city: '',
          verificationStatus: newStatus,
          verificationNote: decision === 'reject' ? reason.trim() : null,
          barcodeEnabled: false,
          reservationExpirationMinutes: 120,
          averageRating: 0,
          ratingCount: 0,
          planTier: 'free',
          isOpen: true,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      } else {
        await profileRef.set({
          userId: targetUserId,
          companyName: 'My Company',
          contactName: '',
          phone: '',
          email: '',
          address: '',
          suppliedCategories: [],
          verificationStatus: newStatus,
          verificationNote: decision === 'reject' ? reason.trim() : null,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }
    }

    // notify user
    await db.collection('notifications').add({
      userId: targetUserId,
      type: 'accountVerification',
      title: decision === 'approve' ? 'Account verified' : 'Verification rejected',
      message: decision === 'approve' ? 'Your account has been verified. You now have full access.' : `Your account verification was rejected: ${reason}`,
      relatedRecordId: targetUserId,
      relatedRecordType: 'user',
      read: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    res.json({ status: newStatus });
  } catch (e) {
    res.status(400).json({ error: e.message || 'Verification failed.' });
  }
});

app.post('/setAccountStatus', verifyAuth, async (req, res) => {
  try {
    const uid = req.uid;
    const adminSnap = await db.collection('users').doc(uid).get();
    if (!adminSnap.exists || adminSnap.data().role !== 'admin') return res.status(403).json({ error: 'forbidden' });
    const { targetUserId, status, reason } = req.body || {};
    if (!targetUserId || !status) return badRequest(res, 'Missing required fields.');
    if (!reason || !reason.trim()) return badRequest(res, 'A reason is required for this action.');
    if (targetUserId === uid) return badRequest(res, 'You cannot change your own account status.');

    const targetRef = db.collection('users').doc(targetUserId);
    const targetSnap = await targetRef.get();
    if (!targetSnap.exists) return badRequest(res, 'Account not found.');

    const role = targetSnap.data().role;
    const collection = role === 'supplier' ? 'suppliers' : 'stores';
    const profileRef = db.collection(collection).doc(targetUserId);
    const profileSnap = await profileRef.get();

    await targetRef.update({
      status,
      statusReason: reason.trim(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    if (profileSnap.exists) {
      await profileRef.update({
        verificationStatus: status === 'active' ? 'active' : status,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }

    await db.collection('notifications').add({
      userId: targetUserId,
      type: 'securityAlert',
      title: 'Account status changed',
      message: `Your account is now ${status}. Reason: ${reason.trim()}`,
      relatedRecordId: targetUserId,
      relatedRecordType: 'user',
      read: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    res.json({ status });
  } catch (e) {
    res.status(400).json({ error: e.message || 'Status change failed.' });
  }
});

app.post('/submitStoreReview', verifyAuth, async (req, res) => {
  try {
    const uid = req.uid;
    const { orderId, rating, feedback } = req.body || {};
    if (!orderId) return badRequest(res, 'Missing orderId.');
    if (!Number.isInteger(rating) || rating < 1 || rating > 5) return badRequest(res, 'Rating must be a whole number from 1 to 5.');
    if (!feedback || !feedback.trim()) return badRequest(res, 'Feedback is required.');

    const consumerSnap = await db.collection('users').doc(uid).get();
    const consumer = consumerSnap.exists ? consumerSnap.data() : {};

    const reviewRef = db.collection('store_reviews').doc(orderId);

    await db.runTransaction(async (tx) => {
      const orderRef = db.collection('orders').doc(orderId);
      const orderSnap = await tx.get(orderRef);
      if (!orderSnap.exists) throw new Error('Order not found.');
      const order = orderSnap.data();
      if (order.consumerId !== uid) throw new Error('You can only review your own orders.');
      if (order.status !== 'completed') throw new Error('You can only review a store after your order is completed.');

      const existingSnap = await tx.get(reviewRef);
      if (existingSnap.exists) throw new Error('You have already reviewed this order. Edit your existing review instead.');

      const storeRef = db.collection('stores').doc(order.storeId);
      const storeSnap = await tx.get(storeRef);
      if (storeSnap.exists) {
        const store = storeSnap.data();
        const oldCount = store.ratingCount || 0;
        const oldAvg = store.averageRating || 0;
        const newCount = oldCount + 1;
        const newAvg = (oldAvg * oldCount + rating) / newCount;
        tx.update(storeRef, { averageRating: newAvg, ratingCount: newCount, updatedAt: admin.firestore.FieldValue.serverTimestamp() });
      }

      tx.set(reviewRef, {
        storeId: order.storeId,
        consumerId: uid,
        consumerName: consumer.fullName || order.consumerName || '',
        orderId,
        rating,
        feedback: feedback.trim(),
        merchantResponse: null,
        merchantResponseAt: null,
        reported: false,
        reportReason: null,
        hidden: false,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      tx.update(orderRef, { reviewed: true, updatedAt: admin.firestore.FieldValue.serverTimestamp() });
    });

    const orderSnap = await db.collection('orders').doc(orderId).get();
    const order = orderSnap.exists ? orderSnap.data() : null;
    if (order) {
      await db.collection('notifications').add({
        userId: order.merchantId,
        type: 'reviewReceived',
        title: 'New store review',
        message: `${consumer.fullName || 'A consumer'} left a ${rating}-star review for ${order.storeName}.`,
        relatedRecordId: orderId,
        relatedRecordType: 'store_review',
        read: false,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }

    res.json({ reviewId: orderId });
  } catch (e) {
    res.status(400).json({ error: e.message || 'Could not submit review.' });
  }
});

app.post('/editStoreReview', verifyAuth, async (req, res) => {
  try {
    const uid = req.uid;
    const { reviewId, rating, feedback } = req.body || {};
    if (!reviewId) return badRequest(res, 'Missing reviewId.');
    if (!Number.isInteger(rating) || rating < 1 || rating > 5) return badRequest(res, 'Rating must be a whole number from 1 to 5.');
    if (!feedback || !feedback.trim()) return badRequest(res, 'Feedback is required.');

    const EDIT_WINDOW_MS = 7 * 24 * 60 * 60 * 1000;

    await db.runTransaction(async (tx) => {
      const reviewRef = db.collection('store_reviews').doc(reviewId);
      const reviewSnap = await tx.get(reviewRef);
      if (!reviewSnap.exists) throw new Error('Review not found.');
      const review = reviewSnap.data();
      if (review.consumerId !== uid) throw new Error('You can only edit your own review.');
      const createdAtMs = review.createdAt ? review.createdAt.toMillis() : Date.now();
      if (Date.now() - createdAtMs > EDIT_WINDOW_MS) throw new Error('The edit window for this review has passed.');

      const storeRef = db.collection('stores').doc(review.storeId);
      const storeSnap = await tx.get(storeRef);
      if (storeSnap.exists && rating !== review.rating) {
        const store = storeSnap.data();
        const count = store.ratingCount || 1;
        const oldAvg = store.averageRating || 0;
        const newAvg = (oldAvg * count - review.rating + rating) / count;
        tx.update(storeRef, { averageRating: newAvg, updatedAt: admin.firestore.FieldValue.serverTimestamp() });
      }

      tx.update(reviewRef, { rating, feedback: feedback.trim(), updatedAt: admin.firestore.FieldValue.serverTimestamp() });
    });

    res.json({ status: 'updated' });
  } catch (e) {
    res.status(400).json({ error: e.message || 'Could not update review.' });
  }
});

﻿app.post('/processPayment', verifyAuth, async (req, res) => {
  try {
    const uid = req.uid;
    const { orderId, simulateOutcome } = req.body || {};
    if (!orderId) return badRequest(res, 'Missing orderId.');
    if (simulateOutcome !== 'success' && simulateOutcome !== 'fail') return badRequest(res, 'Invalid simulateOutcome.');

    const RETRYABLE = new Set(['pendingPayment', 'paymentFailed']);

    await db.runTransaction(async (tx) => {
      const orderRef = db.collection('orders').doc(orderId);
      const orderSnap = await tx.get(orderRef);
      if (!orderSnap.exists) throw new Error('Order not found.');
      const order = orderSnap.data();

      if (order.consumerId !== uid) throw new Error('You are not authorized to pay for this order.');
      if (order.paymentMethod === 'cashOnDelivery') throw new Error('Cash on delivery orders do not require online payment.');
      if (!RETRYABLE.has(order.status)) throw new Error('This order is already ' + order.status + '.');

      const wasHeld = order.status === 'pendingPayment';
      const items = order.items || [];
      const productRefs = items.map((i) => db.collection('products').doc(i.productId));
      const productSnaps = await Promise.all(productRefs.map((r) => tx.get(r)));

      const storeRef = db.collection('stores').doc(order.storeId);
      const storeSnap = await tx.get(storeRef);
      const store = storeSnap.exists ? storeSnap.data() : { name: order.storeName, phone: '', email: '' };

      const paymentRef = db.collection('payments').doc(orderId);

      if (simulateOutcome === 'success') {
        let cogs = 0;
        productSnaps.forEach((snap, idx) => {
          const qty = items[idx].quantity;
          if (!snap.exists) return;
          const product = snap.data();
          const current = product.currentStock || 0;
          const reserved = product.reservedStock || 0;
          cogs += (product.costPrice || 0) * qty;

          if (wasHeld) {
            const newReserved = Math.max(0, reserved - qty);
            const newCurrent = Math.max(0, current - qty);
            tx.update(productRefs[idx], { currentStock: newCurrent, reservedStock: newReserved, updatedAt: admin.firestore.FieldValue.serverTimestamp() });
            const movementRef = db.collection('inventory_movements').doc();
            tx.set(movementRef, {
              productId: snap.id,
              storeId: product.storeId,
              type: 'sale',
              quantityBefore: current,
              quantityChanged: -qty,
              quantityAfter: newCurrent,
              reason: 'Payment successful',
              relatedOrderId: orderId,
              relatedReservationId: null,
              relatedDeliveryId: null,
              performedByUserId: uid,
              performedByName: order.consumerName || '',
              createdAt: admin.firestore.FieldValue.serverTimestamp(),
            });
          } else {
            const available = current - reserved;
            if (qty > available) throw new Error(product.name + ' no longer has enough stock (only ' + available + ' left).');
            const newCurrent = current - qty;
            tx.update(productRefs[idx], { currentStock: newCurrent, updatedAt: admin.firestore.FieldValue.serverTimestamp() });
            const movementRef = db.collection('inventory_movements').doc();
            tx.set(movementRef, {
              productId: snap.id,
              storeId: product.storeId,
              type: 'sale',
              quantityBefore: current,
              quantityChanged: -qty,
              quantityAfter: newCurrent,
              reason: 'Payment successful (retry after earlier failure)',
              relatedOrderId: orderId,
              relatedReservationId: null,
              relatedDeliveryId: null,
              performedByUserId: uid,
              performedByName: order.consumerName || '',
              createdAt: admin.firestore.FieldValue.serverTimestamp(),
            });
          }
        });

        tx.update(orderRef, { status: 'confirmed', updatedAt: admin.firestore.FieldValue.serverTimestamp() });
        tx.update(paymentRef, {
          status: 'successful',
          providerReference: 'SIM-' + Math.random().toString(36).slice(2, 10).toUpperCase(),
          failureReason: null,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        const receiptRef = db.collection('digital_receipts').doc(orderId);
        const receiptNumber = 'SLW-' + new Date().getFullYear() + '-' + orderId.slice(0, 8).toUpperCase();
        tx.set(receiptRef, {
          receiptNumber,
          orderId,
          storeName: (store && store.name) || order.storeName,
          storePhone: (store && store.phone) || '',
          storeEmail: (store && store.email) || '',
          consumerName: order.consumerName,
          items: order.items,
          subtotal: order.subtotal,
          deliveryFee: order.deliveryFee || 0,
          discount: order.discount || 0,
          platformFee: order.platformFee || 0,
          total: order.total,
          paymentMethod: order.paymentMethod,
          paymentStatus: 'successful',
          orderStatus: 'confirmed',
          transactionReference: orderId,
          issuedAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        const transactionRef = db.collection('transactions').doc(orderId);
        tx.set(transactionRef, {
          orderId,
          storeId: order.storeId,
          merchantId: order.merchantId,
          consumerId: order.consumerId,
          type: 'sale',
          amount: order.total,
          subtotal: order.subtotal,
          cogs: Math.round(cogs * 100) / 100,
          paymentMethod: order.paymentMethod,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      } else {
        if (wasHeld) {
          productSnaps.forEach((snap, idx) => {
            const qty = items[idx].quantity;
            if (!snap.exists) return;
            const product = snap.data();
            const reserved = product.reservedStock || 0;
            const newReserved = Math.max(0, reserved - qty);
            tx.update(productRefs[idx], { reservedStock: newReserved, updatedAt: admin.firestore.FieldValue.serverTimestamp() });
            const movementRef = db.collection('inventory_movements').doc();
            tx.set(movementRef, {
              productId: snap.id,
              storeId: product.storeId,
              type: 'reservationReleased',
              quantityBefore: reserved,
              quantityChanged: -qty,
              quantityAfter: newReserved,
              reason: 'Payment failed - stock released',
              relatedOrderId: orderId,
              relatedReservationId: null,
              relatedDeliveryId: null,
              performedByUserId: uid,
              performedByName: order.consumerName || '',
              createdAt: admin.firestore.FieldValue.serverTimestamp(),
            });
          });
        }
        tx.update(orderRef, { status: 'paymentFailed', updatedAt: admin.firestore.FieldValue.serverTimestamp() });
        tx.update(paymentRef, {
          status: 'failed',
          failureReason: 'Simulated payment failure (test mode).',
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }
    });

    const orderSnap = await db.collection('orders').doc(orderId).get();
    const order = orderSnap.exists ? orderSnap.data() : null;
    if (order) {
      const success = simulateOutcome === 'success';
      await db.collection('notifications').add({
        userId: order.consumerId,
        type: success ? 'paymentSuccessful' : 'paymentFailed',
        title: success ? 'Payment successful' : 'Payment failed',
        message: success
          ? 'Your payment of P' + order.total + ' for ' + order.storeName + ' was successful.'
          : 'Your payment for ' + order.storeName + ' could not be processed. Please try again.',
        relatedRecordId: orderId,
        relatedRecordType: 'order',
        read: false,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      if (success) {
        await db.collection('notifications').add({
          userId: order.merchantId,
          type: 'paymentSuccessful',
          title: 'Payment received',
          message: 'Payment of P' + order.total + ' received for order from ' + order.consumerName + '.',
          relatedRecordId: orderId,
          relatedRecordType: 'order',
          read: false,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }
    }

    res.json({ status: simulateOutcome === 'success' ? 'confirmed' : 'paymentFailed' });
  } catch (e) {
    res.status(400).json({ error: e.message || 'Payment could not be processed.' });
  }
});

const PORT = process.env.PORT || 8080;
app.listen(PORT, () => console.log(`API running on ${PORT}`));
const NEXT_STATUS = {
  preparing: 'preparing',
  readyForPickup: 'readyForPickup',
  outForDelivery: 'outForDelivery',
  completed: 'completed',
  cancel: 'cancelled',
  refund: 'refunded',
};
const MERCHANT_ACTIONS = new Set(['preparing', 'readyForPickup', 'outForDelivery', 'completed', 'cancel', 'refund']);
const CONSUMER_ACTIONS = new Set(['cancel']);
const ALLOWED_FROM = {
  preparing: ['confirmed'],
  readyForPickup: ['preparing'],
  outForDelivery: ['preparing'],
  completed: ['readyForPickup', 'outForDelivery'],
  cancel: ['pendingPayment', 'confirmed', 'preparing'],
  refund: ['completed'],
};
const STOCK_ALREADY_SOLD_STATUSES = new Set(['confirmed', 'preparing']);

app.post('/updateOrderStatus', verifyAuth, async (req, res) => {
  try {
    const uid = req.uid;
    const { orderId, action, reason } = req.body || {};
    if (!orderId || !action) return badRequest(res, 'Missing orderId or action.');
    if (!Object.prototype.hasOwnProperty.call(NEXT_STATUS, action)) return badRequest(res, 'Invalid action.');

    await db.runTransaction(async (tx) => {
      const orderRef = db.collection('orders').doc(orderId);
      const orderSnap = await tx.get(orderRef);
      if (!orderSnap.exists) throw new Error('Order not found.');
      const order = orderSnap.data();

      const isMerchant = MERCHANT_ACTIONS.has(action) && order.merchantId === uid;
      const isConsumer = CONSUMER_ACTIONS.has(action) && order.consumerId === uid;
      if (!isMerchant && !isConsumer) throw new Error('You are not authorized to perform this action.');

      if (action === 'readyForPickup' && order.fulfillmentType !== 'pickup') throw new Error('This order is for delivery, not pickup.');
      if (action === 'outForDelivery' && order.fulfillmentType !== 'delivery') throw new Error('This order is for pickup, not delivery.');

      if (!ALLOWED_FROM[action].includes(order.status)) {
        throw new Error(`Cannot ${action} an order that is ${order.status}.`);
      }

      const items = order.items || [];

      if (action === 'cancel' && STOCK_ALREADY_SOLD_STATUSES.has(order.status)) {
        const productRefs = items.map((i) => db.collection('products').doc(i.productId));
        const productSnaps = await Promise.all(productRefs.map((r) => tx.get(r)));
        productSnaps.forEach((productSnap, idx) => {
          if (!productSnap.exists) return;
          const item = items[idx];
          const product = productSnap.data();
          const current = product.currentStock || 0;
          const newCurrent = current + item.quantity;
          tx.update(productRefs[idx], { currentStock: newCurrent, updatedAt: admin.firestore.FieldValue.serverTimestamp() });

          const movementRef = db.collection('inventory_movements').doc();
          tx.set(movementRef, {
            productId: item.productId,
            storeId: order.storeId,
            type: 'returned',
            quantityBefore: current,
            quantityChanged: item.quantity,
            quantityAfter: newCurrent,
            reason: 'Order cancelled — stock returned',
            relatedOrderId: orderId,
            relatedReservationId: null,
            relatedDeliveryId: null,
            performedByUserId: uid,
            performedByName: order.consumerName || '',
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
          });
        });
      } else if (action === 'cancel' && order.status === 'pendingPayment') {
        const productRefs = items.map((i) => db.collection('products').doc(i.productId));
        const productSnaps = await Promise.all(productRefs.map((r) => tx.get(r)));

        productSnaps.forEach((productSnap, idx) => {
          if (!productSnap.exists) return;
          const item = items[idx];
          const product = productSnap.data();
          const reserved = product.reservedStock || 0;
          const newReserved = Math.max(0, reserved - item.quantity);
          tx.update(productRefs[idx], { reservedStock: newReserved, updatedAt: admin.firestore.FieldValue.serverTimestamp() });

          const movementRef = db.collection('inventory_movements').doc();
          tx.set(movementRef, {
            productId: item.productId,
            storeId: order.storeId,
            type: 'reservationReleased',
            quantityBefore: reserved,
            quantityChanged: -item.quantity,
            quantityAfter: newReserved,
            reason: 'Order cancelled — held stock released',
            relatedOrderId: orderId,
            relatedReservationId: null,
            relatedDeliveryId: null,
            performedByUserId: uid,
            performedByName: order.consumerName || '',
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
          });
        });
      }

      const newStatus = NEXT_STATUS[action];
      tx.update(orderRef, {
        status: newStatus,
        cancellationReason: action === 'cancel' ? (reason || null) : (order.cancellationReason || null),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      if (action === 'refund') {
        const paymentRef = db.collection('payments').doc(orderId);
        const paymentSnap = await tx.get(paymentRef);
        if (paymentSnap.exists) {
          tx.update(paymentRef, { status: 'refunded', updatedAt: admin.firestore.FieldValue.serverTimestamp() });
        }
        const transactionRef = db.collection('transactions').doc(orderId);
        const transactionSnap = await tx.get(transactionRef);
        if (transactionSnap.exists) {
          tx.update(transactionRef, { reversed: true, reversedAt: admin.firestore.FieldValue.serverTimestamp() });
        }
      }
    });

    const orderSnap = await db.collection('orders').doc(orderId).get();
    const order = orderSnap.exists ? orderSnap.data() : null;
    if (order) {
      const notifyTargetId = uid === order.merchantId ? order.consumerId : order.merchantId;
      await db.collection('notifications').add({
        userId: notifyTargetId,
        type: 'orderStatusUpdate',
        title: 'Order update',
        message: `Your order from ${order.storeName} is now ${NEXT_STATUS[action]}.`,
        relatedRecordId: orderId,
        relatedRecordType: 'order',
        read: false,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }

    res.json({ status: NEXT_STATUS[action] });
  } catch (e) {
    res.status(400).json({ error: e.message || 'Could not update order.' });
  }
});

const RELEASING_ACTIONS = new Set(['reject', 'cancel']);
const RES_MERCHANT_ACTIONS = new Set(['approve', 'reject', 'preparing', 'readyForPickup', 'outForDelivery', 'completed']);
const RES_CONSUMER_ACTIONS = new Set(['cancel']);
const RES_NEXT_STATUS = {
  approve: 'approved',
  reject: 'rejected',
  preparing: 'preparing',
  readyForPickup: 'readyForPickup',
  outForDelivery: 'outForDelivery',
  completed: 'completed',
  cancel: 'cancelled',
};
const RES_ALLOWED_FROM = {
  approve: ['pending'],
  reject: ['pending'],
  preparing: ['approved'],
  readyForPickup: ['preparing'],
  outForDelivery: ['preparing'],
  completed: ['readyForPickup', 'outForDelivery'],
  cancel: ['pending', 'approved', 'preparing'],
};

app.post('/updateReservationStatus', verifyAuth, async (req, res) => {
  try {
    const uid = req.uid;
    const { reservationId, action, reason } = req.body || {};
    if (!reservationId || !action) return badRequest(res, 'Missing reservationId or action.');
    if (!Object.prototype.hasOwnProperty.call(RES_NEXT_STATUS, action)) return badRequest(res, 'Invalid action.');

    await db.runTransaction(async (tx) => {
      const reservationRef = db.collection('reservations').doc(reservationId);
      const reservationSnap = await tx.get(reservationRef);
      if (!reservationSnap.exists) throw new Error('Reservation not found.');
      const reservation = reservationSnap.data();

      const isMerchant = RES_MERCHANT_ACTIONS.has(action) && reservation.merchantId === uid;
      const isConsumer = RES_CONSUMER_ACTIONS.has(action) && reservation.consumerId === uid;
      if (!isMerchant && !isConsumer) throw new Error('You are not authorized to perform this action.');

      if (!RES_ALLOWED_FROM[action].includes(reservation.status)) {
        throw new Error(`Cannot ${action} a reservation that is ${reservation.status}.`);
      }

      const newStatus = RES_NEXT_STATUS[action];
      const productRef = db.collection('products').doc(reservation.productId);
      const productSnap = await tx.get(productRef);

      if ((RELEASING_ACTIONS.has(action) || action === 'completed') && productSnap.exists) {
        const product = productSnap.data();
        const reserved = product.reservedStock || 0;
        const current = product.currentStock || 0;

        if (RELEASING_ACTIONS.has(action)) {
          const newReserved = Math.max(0, reserved - reservation.quantity);
          tx.update(productRef, { reservedStock: newReserved, updatedAt: admin.firestore.FieldValue.serverTimestamp() });
          const movementRef = db.collection('inventory_movements').doc();
          tx.set(movementRef, {
            productId: reservation.productId,
            storeId: reservation.storeId,
            type: 'reservationReleased',
            quantityBefore: reserved,
            quantityChanged: -reservation.quantity,
            quantityAfter: newReserved,
            reason: action === 'reject' ? `Reservation rejected: ${reason || 'no reason given'}` : 'Reservation cancelled',
            relatedOrderId: null,
            relatedReservationId: reservationId,
            relatedDeliveryId: null,
            performedByUserId: uid,
            performedByName: reservation.consumerName || reservation.storeName || '',
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
          });
        } else if (action === 'completed') {
          const newReserved = Math.max(0, reserved - reservation.quantity);
          const newCurrent = Math.max(0, current - reservation.quantity);
          tx.update(productRef, {
            reservedStock: newReserved,
            currentStock: newCurrent,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
          const movementRef = db.collection('inventory_movements').doc();
          tx.set(movementRef, {
            productId: reservation.productId,
            storeId: reservation.storeId,
            type: 'sale',
            quantityBefore: current,
            quantityChanged: -reservation.quantity,
            quantityAfter: newCurrent,
            reason: 'Reservation completed — claimed/delivered',
            relatedOrderId: null,
            relatedReservationId: reservationId,
            relatedDeliveryId: null,
            performedByUserId: uid,
            performedByName: reservation.consumerName || '',
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
          });
        }
      }

      tx.update(reservationRef, {
        status: newStatus,
        rejectionReason: action === 'reject' ? (reason || null) : (reservation.rejectionReason || null),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    });

    const reservationSnap = await db.collection('reservations').doc(reservationId).get();
    const reservation = reservationSnap.exists ? reservationSnap.data() : null;
    if (reservation) {
      const notifyConsumerTypes = { approve: 'reservationApproved', reject: 'reservationRejected' };
      const notifType = notifyConsumerTypes[action];
      if (notifType) {
        await db.collection('notifications').add({
          userId: reservation.consumerId,
          type: notifType,
          title: action === 'approve' ? 'Reservation approved' : 'Reservation rejected',
          message: action === 'approve'
            ? `Your reservation for ${reservation.productName} at ${reservation.storeName} was approved.`
            : `Your reservation for ${reservation.productName} was rejected${reason ? `: ${reason}` : '.'}`,
          relatedRecordId: reservationId,
          relatedRecordType: 'reservation',
          read: false,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }
    }

    res.json({ status: RES_NEXT_STATUS[action] });
  } catch (e) {
    res.status(400).json({ error: e.message || 'Could not update reservation.' });
  }
});

app.post('/subscribeToPremium', verifyAuth, async (req, res) => {
  try {
    const uid = req.uid;
    const userSnap = await db.collection('users').doc(uid).get();
    if (!userSnap.exists || userSnap.data().role !== 'merchant') return badRequest(res, 'Only merchant accounts can subscribe.');

    const subscriptionRef = db.collection('subscriptions').doc(uid);
    const existingSnap = await subscriptionRef.get();
    const now = Date.now();
    const currentExpiry = existingSnap.exists ? (existingSnap.data().expiresAt ? existingSnap.data().expiresAt.toMillis() : null) : null;
    const base = (currentExpiry && currentExpiry > now) ? currentExpiry : now;
    const expiresAtMs = base + 30 * 24 * 60 * 60 * 1000;
    const expiresAt = admin.firestore.Timestamp.fromMillis(expiresAtMs);

    await subscriptionRef.set({
      merchantId: uid,
      storeId: uid,
      planId: 'premium',
      tier: 'premium',
      startedAt: existingSnap.exists ? (existingSnap.data().startedAt || admin.firestore.FieldValue.serverTimestamp()) : admin.firestore.FieldValue.serverTimestamp(),
      expiresAt,
      autoRenew: false,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      createdAt: existingSnap.exists ? (existingSnap.data().createdAt || admin.firestore.FieldValue.serverTimestamp()) : admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });

    await db.collection('notifications').add({
      userId: uid,
      type: 'general',
      title: 'Premium activated',
      message: 'Your Salwana Premium subscription is now active.',
      relatedRecordId: uid,
      relatedRecordType: 'subscription',
      read: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    res.json({ expiresAtIso: new Date(expiresAtMs).toISOString() });
  } catch (e) {
    res.status(400).json({ error: e.message || 'Could not activate Premium.' });
  }
});

