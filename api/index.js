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

const PORT = process.env.PORT || 8080;
app.listen(PORT, () => console.log(`API running on ${PORT}`));
