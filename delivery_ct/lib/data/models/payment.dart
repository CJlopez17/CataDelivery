import 'package:delivery_ct/data/models/address.dart';

class PaymentArguments {
  final int storeId;
  final Address address;
  final double subtotal;
  final double deliveryFee;
  final String? orderComment;

  PaymentArguments({
    required this.storeId,
    required this.address,
    required this.subtotal,
    required this.deliveryFee,
    this.orderComment,
  });

  double get total => subtotal + deliveryFee;
}