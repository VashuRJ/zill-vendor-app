import 'package:flutter_test/flutter_test.dart';
import 'package:vendor_app/features/menu/viewmodel/menu_viewmodel.dart';

void main() {
  // ─────────────────────────────────────────────────────────────────────────
  // MenuItem.fromJson
  // ─────────────────────────────────────────────────────────────────────────
  group('MenuItem.fromJson', () {
    Map<String, dynamic> baseMenuItemJson() => {
          'id': 101,
          'name': 'Paneer Butter Masala',
          'description': 'Rich and creamy paneer curry',
          'price': '220.00',
          'discounted_price': '199.00',
          'effective_price': '199.00',
          'image_url': 'https://cdn.example.com/pbm.jpg',
          'is_veg': true,
          'is_vegan': false,
          'is_gluten_free': false,
          'spice_level': 'medium',
          'calories': 450,
          'preparation_time': 20,
          'serves': 2,
          'is_featured': true,
          'is_bestseller': true,
          'is_new': false,
          'category': 5,
          'category_name': 'Main Course',
          'is_available': true,
        };

    test('parses all fields correctly', () {
      final item = MenuItem.fromJson(baseMenuItemJson());

      expect(item.id, 101);
      expect(item.name, 'Paneer Butter Masala');
      expect(item.description, 'Rich and creamy paneer curry');
      expect(item.price, 220.0);
      expect(item.discountedPrice, 199.0);
      expect(item.effectivePrice, 199.0);
      expect(item.imageUrl, 'https://cdn.example.com/pbm.jpg');
      expect(item.isVeg, isTrue);
      expect(item.isVegan, isFalse);
      expect(item.isGlutenFree, isFalse);
      expect(item.spiceLevel, 'medium');
      expect(item.calories, 450);
      expect(item.preparationTime, 20);
      expect(item.serves, 2);
      expect(item.isFeatured, isTrue);
      expect(item.isBestseller, isTrue);
      expect(item.isNew, isFalse);
      expect(item.categoryId, 5);
      expect(item.categoryName, 'Main Course');
      expect(item.isAvailable, isTrue);
    });

    test('uses safe defaults when all fields missing', () {
      final item = MenuItem.fromJson({});

      expect(item.id, 0);
      expect(item.name, '');
      expect(item.price, 0.0);
      expect(item.discountedPrice, isNull);
      expect(item.isVeg, isFalse);
      expect(item.spiceLevel, 'none');
      expect(item.isFeatured, isFalse);
      expect(item.categoryName, 'Other');
      expect(item.isAvailable, isTrue); // default available
    });

    test('discountedPrice is null when not in JSON', () {
      final json = baseMenuItemJson()..remove('discounted_price');
      final item = MenuItem.fromJson(json);
      expect(item.discountedPrice, isNull);
    });

    test('effectivePrice falls back to price when effective_price missing', () {
      final json = baseMenuItemJson()..remove('effective_price');
      json['price'] = '250.00';
      final item = MenuItem.fromJson(json);
      expect(item.effectivePrice, 250.0);
    });

    test('is_available defaults to true when missing', () {
      final json = baseMenuItemJson()..remove('is_available');
      final item = MenuItem.fromJson(json);
      expect(item.isAvailable, isTrue);
    });

    test('isAvailable can be mutated (vendor toggle)', () {
      final item = MenuItem.fromJson(baseMenuItemJson());
      expect(item.isAvailable, isTrue);
      item.isAvailable = false;
      expect(item.isAvailable, isFalse);
    });

    test('parses price as string correctly', () {
      final json = baseMenuItemJson()..['price'] = '1299.50';
      final item = MenuItem.fromJson(json);
      expect(item.price, 1299.5);
    });

    test('parses price as num correctly', () {
      final json = baseMenuItemJson()..['price'] = 350; // integer, not string
      final item = MenuItem.fromJson(json);
      expect(item.price, 350.0);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // MenuItem.matchesSearch
  // ─────────────────────────────────────────────────────────────────────────
  group('MenuItem.matchesSearch', () {
    late MenuItem item;

    setUp(() {
      item = MenuItem.fromJson({
        'id': 1,
        'name': 'Chicken Biryani',
        'description': 'Aromatic basmati rice with spiced chicken',
        'price': '180',
        'effective_price': '180',
        'image_url': '',
        'is_veg': false,
        'is_vegan': false,
        'is_gluten_free': false,
        'spice_level': 'hot',
        'is_featured': false,
        'is_bestseller': false,
        'is_new': false,
        'category_name': 'Rice',
        'is_available': true,
      });
    });

    test('returns true for empty query (show all)', () {
      expect(item.matchesSearch(''), isTrue);
    });

    test('matches on item name (case-insensitive)', () {
      expect(item.matchesSearch('biryani'), isTrue);
      expect(item.matchesSearch('BIRYANI'), isTrue);
      expect(item.matchesSearch('Chicken'), isTrue);
    });

    test('matches on description (case-insensitive)', () {
      expect(item.matchesSearch('basmati'), isTrue);
      expect(item.matchesSearch('AROMATIC'), isTrue);
    });

    test('returns false for non-matching query', () {
      expect(item.matchesSearch('pizza'), isFalse);
      expect(item.matchesSearch('xyz123'), isFalse);
    });

    test('matches partial string', () {
      expect(item.matchesSearch('chick'), isTrue);
      expect(item.matchesSearch('birya'), isTrue);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // MenuCategory.fromJson
  // ─────────────────────────────────────────────────────────────────────────
  group('MenuCategory.fromJson', () {
    test('parses all fields correctly', () {
      final json = {
        'id': 3,
        'name': 'Starters',
        'description': 'Appetizers and snacks',
        'image_url': 'https://cdn.example.com/starters.jpg',
        'display_order': 1,
        'items': [
          {
            'id': 11,
            'name': 'Samosa',
            'description': 'Crispy samosa',
            'price': '25.00',
            'effective_price': '25.00',
            'image_url': '',
            'is_veg': true,
            'is_vegan': true,
            'is_gluten_free': false,
            'spice_level': 'mild',
            'is_featured': false,
            'is_bestseller': false,
            'is_new': false,
            'category_name': 'Starters',
            'is_available': true,
          },
        ],
      };

      final cat = MenuCategory.fromJson(json);

      expect(cat.id, 3);
      expect(cat.name, 'Starters');
      expect(cat.description, 'Appetizers and snacks');
      expect(cat.imageUrl, 'https://cdn.example.com/starters.jpg');
      expect(cat.displayOrder, 1);
      expect(cat.items.length, 1);
      expect(cat.items.first.name, 'Samosa');
    });

    test('uses defaults for missing fields', () {
      final cat = MenuCategory.fromJson({});

      expect(cat.id, 0);
      expect(cat.name, '');
      expect(cat.imageUrl, isNull);
      expect(cat.displayOrder, 0);
      expect(cat.items, isEmpty);
    });

    test('ignores non-map entries in items list', () {
      final cat = MenuCategory.fromJson({
        'id': 1,
        'name': 'Test',
        'description': '',
        'display_order': 0,
        'items': ['invalid', null, 42],
      });
      expect(cat.items, isEmpty);
    });

    test('imageUrl is null when not in JSON', () {
      final cat = MenuCategory.fromJson({
        'id': 1,
        'name': 'Test',
        'description': '',
        'display_order': 0,
      });
      expect(cat.imageUrl, isNull);
    });
  });
}
