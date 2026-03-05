import 'package:flutter_test/flutter_test.dart';
import 'package:vendor_app/features/orders/viewmodel/orders_viewmodel.dart';

void main() {
  // ─────────────────────────────────────────────────────────────────────────
  // OrderAddonItem.fromJson
  // ─────────────────────────────────────────────────────────────────────────
  group('OrderAddonItem.fromJson', () {
    test('parses all fields correctly', () {
      final json = {
        'id': 10,
        'addon_name': 'Extra Cheese',
        'addon_price': '15.00',
      };
      final addon = OrderAddonItem.fromJson(json);

      expect(addon.id, 10);
      expect(addon.addonName, 'Extra Cheese');
      expect(addon.addonPrice, 15.0);
    });

    test('uses defaults for missing fields', () {
      final addon = OrderAddonItem.fromJson({});

      expect(addon.id, 0);
      expect(addon.addonName, '');
      expect(addon.addonPrice, 0.0);
    });

    test('parses numeric addon_price as num', () {
      final addon = OrderAddonItem.fromJson({
        'id': 1,
        'addon_name': 'Sauce',
        'addon_price': 5, // integer, not string
      });
      expect(addon.addonPrice, 5.0);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // OrderLineItem.fromJson
  // ─────────────────────────────────────────────────────────────────────────
  group('OrderLineItem.fromJson', () {
    test('parses all fields correctly', () {
      final json = {
        'id': 5,
        'item_name': 'Margherita Pizza',
        'variant_name': 'Large',
        'quantity': 2,
        'unit_price': '299.00',
        'addons_price': '30.00',
        'subtotal': '628.00',
        'preparation_time': 25,
        'special_instructions': 'No onions',
        'menu_item_image': 'https://example.com/pizza.jpg',
        'selected_addons': [
          {'id': 1, 'addon_name': 'Extra Cheese', 'addon_price': '15.00'},
        ],
      };

      final item = OrderLineItem.fromJson(json);

      expect(item.id, 5);
      expect(item.itemName, 'Margherita Pizza');
      expect(item.variantName, 'Large');
      expect(item.quantity, 2);
      expect(item.unitPrice, 299.0);
      expect(item.addonsPrice, 30.0);
      expect(item.subtotal, 628.0);
      expect(item.preparationTime, 25);
      expect(item.specialInstructions, 'No onions');
      expect(item.menuItemImage, 'https://example.com/pizza.jpg');
      expect(item.selectedAddons.length, 1);
      expect(item.selectedAddons.first.addonName, 'Extra Cheese');
    });

    test('uses safe defaults for missing fields', () {
      final item = OrderLineItem.fromJson({});

      expect(item.id, 0);
      expect(item.itemName, 'Item');
      expect(item.variantName, isNull);
      expect(item.quantity, 1);
      expect(item.unitPrice, 0.0);
      expect(item.selectedAddons, isEmpty);
    });

    test('ignores non-map entries in selected_addons', () {
      final item = OrderLineItem.fromJson({
        'selected_addons': ['invalid', null, 123],
      });
      expect(item.selectedAddons, isEmpty);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // VendorOrder.fromJson
  // ─────────────────────────────────────────────────────────────────────────
  group('VendorOrder.fromJson', () {
    Map<String, dynamic> baseOrderJson() => {
          'id': 42,
          'order_number': 'ORD-2025-042',
          'customer_name': 'Rahul Sharma',
          'customer_phone': '9876543210',
          'status': 'pending',
          'grand_total': 450.0,
          'item_count': 3,
          'created_at': '2025-03-01T10:30:00Z',
          'payment_method': 'online',
          'payment_status': 'paid',
          'delivery_address': '123 MG Road, Bengaluru',
          'instructions': 'Ring the bell',
          'items': [],
          'items_summary': ['2x Pizza', '1x Coke'],
          'order_type': 'delivery',
          'is_scheduled': false,
          'accepted_by_restaurant': false,
        };

    test('parses all basic fields correctly', () {
      final order = VendorOrder.fromJson(baseOrderJson());

      expect(order.id, 42);
      expect(order.orderNumber, 'ORD-2025-042');
      expect(order.customerName, 'Rahul Sharma');
      expect(order.customerPhone, '9876543210');
      expect(order.status, 'pending');
      expect(order.totalAmount, 450.0);
      expect(order.itemsCount, 3);
      expect(order.paymentMethod, 'online');
      expect(order.paymentStatus, 'paid');
      expect(order.deliveryAddress, '123 MG Road, Bengaluru');
      expect(order.orderType, 'delivery');
      expect(order.isScheduled, isFalse);
      expect(order.acceptedByRestaurant, isFalse);
    });

    test('parses itemsSummary correctly', () {
      final order = VendorOrder.fromJson(baseOrderJson());
      expect(order.itemsSummary, ['2x Pizza', '1x Coke']);
    });

    test('status is lowercased and trimmed', () {
      final json = baseOrderJson()..['status'] = '  PREPARING  ';
      final order = VendorOrder.fromJson(json);
      expect(order.status, 'preparing');
    });

    test('uses grand_total if present, falls back to total_amount', () {
      final json = baseOrderJson();
      json.remove('grand_total');
      json['total_amount'] = 300.0;
      final order = VendorOrder.fromJson(json);
      expect(order.totalAmount, 300.0);
    });

    test('uses item_count if present, falls back to items_count', () {
      final json = baseOrderJson();
      json.remove('item_count');
      json['items_count'] = 5;
      final order = VendorOrder.fromJson(json);
      expect(order.itemsCount, 5);
    });

    test('handles missing created_at gracefully (does not throw)', () {
      final json = baseOrderJson()..remove('created_at');
      expect(() => VendorOrder.fromJson(json), returnsNormally);
    });

    test('parses scheduled_for when present', () {
      final json = baseOrderJson();
      json['is_scheduled'] = true;
      json['scheduled_for'] = '2025-03-02T19:00:00Z';
      final order = VendorOrder.fromJson(json);

      expect(order.isScheduled, isTrue);
      expect(order.scheduledFor, isNotNull);
      expect(order.scheduledFor!.year, 2025);
    });

    test('scheduledFor is null when not present', () {
      final order = VendorOrder.fromJson(baseOrderJson());
      expect(order.scheduledFor, isNull);
    });

    test('parses estimatedPrepTime', () {
      final json = baseOrderJson()..['estimated_prep_time'] = 30;
      final order = VendorOrder.fromJson(json);
      expect(order.estimatedPrepTime, 30);
    });

    test('uses safe defaults when all fields missing', () {
      final order = VendorOrder.fromJson({});

      expect(order.id, 0);
      expect(order.customerName, 'Customer');
      expect(order.status, 'unknown');
      expect(order.totalAmount, 0.0);
      expect(order.paymentMethod, 'cash');
    });

    test('parses nested items list', () {
      final json = baseOrderJson();
      json['items'] = [
        {
          'id': 1,
          'item_name': 'Burger',
          'quantity': 2,
          'unit_price': '120.00',
          'addons_price': '0',
          'subtotal': '240.00',
        }
      ];
      final order = VendorOrder.fromJson(json);
      expect(order.items.length, 1);
      expect(order.items.first.itemName, 'Burger');
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // VendorOrderDetail.fromJson
  // ─────────────────────────────────────────────────────────────────────────
  group('VendorOrderDetail.fromJson', () {
    test('parses delivery charge and tax amount', () {
      final json = {
        'id': 1,
        'order_number': 'ORD-001',
        'customer_name': 'Test User',
        'customer_phone': '',
        'status': 'pending',
        'grand_total': 500.0,
        'created_at': '2025-03-01T10:00:00Z',
        'payment_method': 'online',
        'payment_status': 'paid',
        'delivery_address': '',
        'instructions': '',
        'items': [],
        'delivery_charge': '40.00',
        'tax_amount': '22.50',
        'discount_amount': '10.00',
        'total_amount': '437.50',
        'delivery_instructions': 'Leave at door',
        'coupon_code': 'SAVE10',
        'coupon_discount': '10.00',
        'cancellation_note': '',
        'cancellation_reason': '',
      };

      final detail = VendorOrderDetail.fromJson(json);

      expect(detail.deliveryCharge, 40.0);
      expect(detail.taxAmount, 22.5);
      expect(detail.discountAmount, 10.0);
      expect(detail.couponCode, 'SAVE10');
      expect(detail.couponDiscount, 10.0);
      expect(detail.deliveryInstructions, 'Leave at door');
    });

    test('uses zero defaults for missing financial fields', () {
      final json = {
        'id': 1,
        'order_number': 'ORD-001',
        'customer_name': 'User',
        'customer_phone': '',
        'status': 'pending',
        'grand_total': 0.0,
        'created_at': '2025-03-01T10:00:00Z',
        'payment_method': 'cash',
        'payment_status': 'pending',
        'delivery_address': '',
        'instructions': '',
        'items': [],
      };
      final detail = VendorOrderDetail.fromJson(json);

      expect(detail.deliveryCharge, 0.0);
      expect(detail.taxAmount, 0.0);
      expect(detail.couponCode, '');
      expect(detail.cancellationNote, '');
    });
  });
}
