import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/constants/firebase_collections.dart';
import '../models/product_model.dart';
import '../models/order_model.dart';

abstract class MarketplaceRemoteDatasource {
  // Products
  Future<List<ProductModel>> getProducts({
    String? category,
    String? sellerId,
    int limit = 20,
    DocumentSnapshot? startAfter,
  });
  Future<ProductModel> getProduct(String id);
  Future<ProductModel> createProduct(ProductModel product);
  Future<ProductModel> updateProduct(ProductModel product);
  Future<void> deleteProduct(String id);
  Future<List<ProductModel>> searchProducts(String query);
  Future<void> incrementViewCount(String productId);
  Stream<List<ProductModel>> watchSellerProducts(String sellerId);

  // Orders
  Future<List<OrderModel>> getBuyerOrders(String buyerId);
  Future<List<OrderModel>> getSellerOrders(String sellerId);
  Future<OrderModel> getOrder(String id);
  Future<OrderModel> createOrder(OrderModel order);
  Future<OrderModel> updateOrderStatus(String orderId, String status);
  Future<OrderModel> updateEscrowStatus(String orderId, String escrowStatus);
  Future<OrderModel> markAsShipped(String orderId, String? trackingNumber);
  Future<OrderModel> confirmDelivery(String orderId);
  Future<OrderModel> releaseEscrow(String orderId);
  Future<OrderModel> cancelOrder(String orderId, String reason);
  Stream<OrderModel> watchOrder(String orderId);
  Stream<List<OrderModel>> watchBuyerOrders(String buyerId);
  Stream<List<OrderModel>> watchSellerOrders(String sellerId);
}

class MarketplaceRemoteDatasourceImpl implements MarketplaceRemoteDatasource {
  final FirebaseFirestore _firestore;

  MarketplaceRemoteDatasourceImpl({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _productsCollection =>
      _firestore.collection(FirebaseCollections.products);

  CollectionReference<Map<String, dynamic>> get _ordersCollection =>
      _firestore.collection(FirebaseCollections.orders);

  // ============ PRODUCTS ============

  @override
  Future<List<ProductModel>> getProducts({
    String? category,
    String? sellerId,
    int limit = 20,
    DocumentSnapshot? startAfter,
  }) async {
    Query<Map<String, dynamic>> query = _productsCollection
        .where('isAvailable', isEqualTo: true)
        .orderBy('createdAt', descending: true);

    if (category != null && category != 'other') {
      query = query.where('category', isEqualTo: category);
    }

    if (sellerId != null) {
      query = query.where('sellerId', isEqualTo: sellerId);
    }

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    query = query.limit(limit);

    final snapshot = await query.get();
    return snapshot.docs.map((doc) => ProductModel.fromFirestore(doc)).toList();
  }

  @override
  Future<ProductModel> getProduct(String id) async {
    final doc = await _productsCollection.doc(id).get();
    if (!doc.exists) {
      throw Exception('Produit non trouve');
    }
    return ProductModel.fromFirestore(doc);
  }

  @override
  Future<ProductModel> createProduct(ProductModel product) async {
    final docRef = _productsCollection.doc();
    final newProduct = product.copyWith(
      id: docRef.id,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await docRef.set(newProduct.toFirestore());
    return newProduct;
  }

  @override
  Future<ProductModel> updateProduct(ProductModel product) async {
    final updatedProduct = product.copyWith(updatedAt: DateTime.now());
    await _productsCollection.doc(product.id).update(updatedProduct.toFirestore());
    return updatedProduct;
  }

  @override
  Future<void> deleteProduct(String id) async {
    await _productsCollection.doc(id).delete();
  }

  @override
  Future<List<ProductModel>> searchProducts(String query) async {
    final queryLower = query.toLowerCase();

    // Search by title (prefix match)
    final snapshot = await _productsCollection
        .where('isAvailable', isEqualTo: true)
        .orderBy('title')
        .startAt([queryLower])
        .endAt(['$queryLower\uf8ff'])
        .limit(20)
        .get();

    return snapshot.docs.map((doc) => ProductModel.fromFirestore(doc)).toList();
  }

  @override
  Future<void> incrementViewCount(String productId) async {
    await _productsCollection.doc(productId).update({
      'viewCount': FieldValue.increment(1),
    });
  }

  @override
  Stream<List<ProductModel>> watchSellerProducts(String sellerId) {
    return _productsCollection
        .where('sellerId', isEqualTo: sellerId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => ProductModel.fromFirestore(doc)).toList());
  }

  // ============ ORDERS ============

  @override
  Future<List<OrderModel>> getBuyerOrders(String buyerId) async {
    final snapshot = await _ordersCollection
        .where('buyerId', isEqualTo: buyerId)
        .orderBy('createdAt', descending: true)
        .get();
    return snapshot.docs.map((doc) => OrderModel.fromFirestore(doc)).toList();
  }

  @override
  Future<List<OrderModel>> getSellerOrders(String sellerId) async {
    final snapshot = await _ordersCollection
        .where('sellerId', isEqualTo: sellerId)
        .orderBy('createdAt', descending: true)
        .get();
    return snapshot.docs.map((doc) => OrderModel.fromFirestore(doc)).toList();
  }

  @override
  Future<OrderModel> getOrder(String id) async {
    final doc = await _ordersCollection.doc(id).get();
    if (!doc.exists) {
      throw Exception('Commande non trouvee');
    }
    return OrderModel.fromFirestore(doc);
  }

  @override
  Future<OrderModel> createOrder(OrderModel order) async {
    final docRef = _ordersCollection.doc();
    final newOrder = order.copyWith(
      id: docRef.id,
      createdAt: DateTime.now(),
    );
    await docRef.set(newOrder.toFirestore());

    // Decrease product quantity
    await _productsCollection.doc(order.productId).update({
      'quantity': FieldValue.increment(-order.quantity),
    });

    return newOrder;
  }

  @override
  Future<OrderModel> updateOrderStatus(String orderId, String status) async {
    final updates = <String, dynamic>{
      'status': status,
    };

    // Add timestamp based on status
    final now = Timestamp.fromDate(DateTime.now());
    switch (status) {
      case 'paid':
        updates['paidAt'] = now;
        updates['escrowStatus'] = 'holding';
        break;
      case 'shipped':
        updates['shippedAt'] = now;
        break;
      case 'delivered':
        updates['deliveredAt'] = now;
        break;
      case 'completed':
        updates['completedAt'] = now;
        updates['escrowStatus'] = 'released';
        break;
      case 'cancelled':
        updates['cancelledAt'] = now;
        break;
      case 'refunded':
        updates['escrowStatus'] = 'refunded';
        break;
    }

    await _ordersCollection.doc(orderId).update(updates);
    return await getOrder(orderId);
  }

  @override
  Future<OrderModel> updateEscrowStatus(String orderId, String escrowStatus) async {
    await _ordersCollection.doc(orderId).update({
      'escrowStatus': escrowStatus,
    });
    return await getOrder(orderId);
  }

  @override
  Future<OrderModel> markAsShipped(String orderId, String? trackingNumber) async {
    final updates = <String, dynamic>{
      'status': 'shipped',
      'shippedAt': Timestamp.fromDate(DateTime.now()),
    };
    if (trackingNumber != null) {
      updates['trackingNumber'] = trackingNumber;
    }
    await _ordersCollection.doc(orderId).update(updates);
    return await getOrder(orderId);
  }

  @override
  Future<OrderModel> confirmDelivery(String orderId) async {
    await _ordersCollection.doc(orderId).update({
      'status': 'delivered',
      'deliveredAt': Timestamp.fromDate(DateTime.now()),
    });
    return await getOrder(orderId);
  }

  @override
  Future<OrderModel> releaseEscrow(String orderId) async {
    await _ordersCollection.doc(orderId).update({
      'status': 'completed',
      'escrowStatus': 'released',
      'completedAt': Timestamp.fromDate(DateTime.now()),
    });
    return await getOrder(orderId);
  }

  @override
  Future<OrderModel> cancelOrder(String orderId, String reason) async {
    final order = await getOrder(orderId);

    await _ordersCollection.doc(orderId).update({
      'status': 'cancelled',
      'cancellationReason': reason,
      'cancelledAt': Timestamp.fromDate(DateTime.now()),
      'escrowStatus': order.escrowStatus == 'holding' ? 'refunded' : order.escrowStatus,
    });

    // Restore product quantity
    await _productsCollection.doc(order.productId).update({
      'quantity': FieldValue.increment(order.quantity),
    });

    return await getOrder(orderId);
  }

  @override
  Stream<OrderModel> watchOrder(String orderId) {
    return _ordersCollection
        .doc(orderId)
        .snapshots()
        .map((doc) => OrderModel.fromFirestore(doc));
  }

  @override
  Stream<List<OrderModel>> watchBuyerOrders(String buyerId) {
    return _ordersCollection
        .where('buyerId', isEqualTo: buyerId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => OrderModel.fromFirestore(doc)).toList());
  }

  @override
  Stream<List<OrderModel>> watchSellerOrders(String sellerId) {
    return _ordersCollection
        .where('sellerId', isEqualTo: sellerId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => OrderModel.fromFirestore(doc)).toList());
  }
}
