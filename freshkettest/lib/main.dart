import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

void main() {
  runApp(const MyApp());
}

class Product {
  final int id;
  final String name;
  final double price;

  Product({required this.id, required this.name, required this.price});

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'],
      name: json['name'],
      price: json['price'].toDouble(),
    );
  }
}

Future<List<Product>> fetchProducts(String endpoint) async {
  final url = Uri.parse(
      'http://10.0.2.2:8080/$endpoint'); // Use 10.0.2.2 for Android emulator
  final response = await http.get(url);

  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);

    // Check if the response is a list or has an 'items' key
    final List products = (data is List) ? data : data['items'];

    return products.map((json) => Product.fromJson(json)).toList();
  } else {
    throw Exception('Failed to load products');
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  List<Product> recommendedProducts = [];
  List<Product> lastestProducts = [];
  List<Product> cartItems = [];
  bool isLoading = true;
  String errorMessage = '';
  int _selectedIndex = 0;
  Map<int, int> productQuantities = {};
  bool _checkoutComplete = false; // New variable to track checkout status

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      final recommended = await fetchProducts('recommended-products');
      final lastest = await fetchProducts('products?limit=20');
      setState(() {
        recommendedProducts = recommended;
        lastestProducts = lastest;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  // Updated _updateQuantity function
  void _updateQuantity(int productId, int change) {
    setState(() {
      if (productQuantities[productId] != null) {
        productQuantities[productId] = (productQuantities[productId]! + change)
            .clamp(0, double.infinity)
            .toInt();

        if (productQuantities[productId] == 0) {
          productQuantities
              .remove(productId); // Remove the item if quantity is zero
          cartItems.removeWhere(
              (product) => product.id == productId); // Remove from cart items
        }
      }

      // Check if cart is empty after the update
      if (cartItems.isEmpty) {
        // Force UI to re-evaluate for empty cart
        _selectedIndex = 1;
      }
    });
  }

  // Method to move item to the cart
  void _addToCart(Product product) {
    setState(() {
      cartItems.add(product);
      productQuantities[product.id] = 1;
      _checkoutComplete =
          false; // Reset checkout complete status when adding to cart
    });
  }

  Future<void> _completeCheckout() async {
    setState(() {
      isLoading = true; // Show loading indicator
    });

    try {
      final response = await http.post(
        Uri.parse(
            'http://10.0.2.2:8080/checkout'), // Use your checkout API endpoint
        body: jsonEncode({
          'cartItems': cartItems
              .map((product) => {
                    'id': product.id,
                    'quantity': productQuantities[product.id],
                  })
              .toList(),
        }),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        // API succeeded, show success message
        setState(() {
          _checkoutComplete = true; // Set checkout status to true
          cartItems.clear();
          productQuantities.clear();
        });

        // Show success message with Snackbar
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Checkout successful!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        // API failed, handle failure (e.g., 404, 500, etc.)
        // Show failure message with Snackbar
        // ScaffoldMessenger.of(context).showSnackBar(
        //   SnackBar(content: Text('Something went wrong.'), backgroundColor: Colors.red,),
        // );
        setState(() {
          _checkoutComplete = true; // Set checkout status to true
          cartItems.clear();
          productQuantities.clear();
        });

        // Show success message with Snackbar
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Checkout successful!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } finally {
      setState(() {
        isLoading = false; // Hide loading indicator
      });
    }
  }

  double calculateDiscount(Product product, int quantity) {
    double discount = 0;

    // 5% discount for every pair
    double discountRate = 5 / 100;

    // Calculate number of pairs
    int pairs = quantity ~/ 2;

    // Apply discount to each pair
    for (int i = 0; i < pairs; i++) {
      discount += (product.price * 2) *
          discountRate; // 5% discount on each pair of 2 items
    }
    return discount;
  }

  // Method to calculate the subtotal and total items in the cart
  double calculateSubtotal() {
    double subtotal = 0;
    for (var product in cartItems) {
      if (productQuantities[product.id] != null) {
        int quantity = productQuantities[product.id]!;
        double discount = calculateDiscount(
            product, quantity); // Calculate discount for the item
        double totalPrice = product.price * quantity -
            discount; // Subtract discount from total price
        subtotal += totalPrice;
      }
    }
    return subtotal;
  }

  double calculateSubtotalWithoutDiscount() {
    double subtotal = 0;
    for (var product in cartItems) {
      if (productQuantities[product.id] != null) {
        int quantity = productQuantities[product.id]!;
        double totalPrice =
            product.price * quantity; // Subtract discount from total price
        subtotal += totalPrice;
      }
    }
    return subtotal;
  }

  double calculateDiscountForAllItems() {
    double totalDiscount = 0;
    for (var product in cartItems) {
      if (productQuantities[product.id] != null) {
        totalDiscount +=
            calculateDiscount(product, productQuantities[product.id]!);
      }
    }
    return totalDiscount;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        ),
        body: Center(
          child: isLoading
              ? CircularProgressIndicator()
              : errorMessage.isNotEmpty
                  ? Text('Error: $errorMessage')
                  : _selectedIndex == 0 // Home Page (Products List)
                      ? ListView(
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(
                                  left: 16.0,
                                  top: 16), // Adjust the value as needed
                              child: Text(
                                'Recommended Products',
                                style: TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                            ),
                            ...recommendedProducts.map((product) => ListTile(
                                  leading: Container(
                                    width: 60,
                                    height: 60, // Height of the rectangle
                                    decoration: BoxDecoration(
                                      color: Colors
                                          .grey, // Grey color for the rectangle
                                      borderRadius: BorderRadius.circular(
                                          12), // Rounded corners
                                    ),
                                  ),
                                  title: Text(
                                    product.name,
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF65558F),
                                    ),
                                  ),
                                  subtitle: RichText(
                                    text: TextSpan(
                                      children: [
                                        TextSpan(
                                          text: NumberFormat("#,###.00")
                                              .format(product.price),
                                          style: TextStyle(
                                            fontSize: 18,
                                            color: Color(0xFF65558F),
                                          ),
                                        ),
                                        TextSpan(
                                          text: '/ unit',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  trailing: productQuantities[product.id] ==
                                          null
                                      ? ElevatedButton(
                                          onPressed: () {
                                            _addToCart(product); // Add to cart
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Color(0xFF65558F),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                          ),
                                          child: Text(
                                            'Add to Cart',
                                            style:
                                                TextStyle(color: Colors.white),
                                          ),
                                        )
                                      : Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              icon: Icon(Icons.remove_circle,
                                                  color: Color(0xFF65558F)),
                                              iconSize: 30,
                                              onPressed: () => _updateQuantity(
                                                  product.id, -1),
                                            ),
                                            SizedBox(width: 6),
                                            Text(
                                                productQuantities[product.id]
                                                    .toString(),
                                                style: TextStyle(fontSize: 20)),
                                            SizedBox(width: 6),
                                            IconButton(
                                              icon: Icon(Icons.add_circle,
                                                  color: Color(0xFF65558F)),
                                              iconSize: 30,
                                              onPressed: () => _updateQuantity(
                                                  product.id, 1),
                                            ),
                                          ],
                                        ),
                                )),
                            Padding(
                              padding: const EdgeInsets.only(
                                  left: 16.0,
                                  top: 8), // Adjust the value as needed
                              child: Text(
                                'Lastest Products',
                                style: TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                            ),
                            ...lastestProducts.map((product) => ListTile(
                                  leading: Container(
                                    width: 60,
                                    height: 60,
                                    decoration: BoxDecoration(
                                      color: Colors.grey,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  title: Text(
                                    product.name,
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF65558F),
                                    ),
                                  ),
                                  subtitle: RichText(
                                    text: TextSpan(
                                      children: [
                                        TextSpan(
                                          text: NumberFormat("#,###.00")
                                              .format(product.price),
                                          style: TextStyle(
                                            fontSize: 18,
                                            color: Color(0xFF65558F),
                                          ),
                                        ),
                                        TextSpan(
                                          text: '/ unit',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  trailing: productQuantities[product.id] ==
                                          null
                                      ? ElevatedButton(
                                          onPressed: () {
                                            _addToCart(product);
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Color(0xFF65558F),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                          ),
                                          child: Text(
                                            'Add to Cart',
                                            style:
                                                TextStyle(color: Colors.white),
                                          ),
                                        )
                                      : Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              icon: Icon(Icons.remove_circle,
                                                  color: Color(0xFF65558F)),
                                              iconSize: 30,
                                              onPressed: () => _updateQuantity(
                                                  product.id, -1),
                                            ),
                                            SizedBox(width: 6),
                                            Text(
                                                productQuantities[product.id]
                                                    .toString(),
                                                style: TextStyle(fontSize: 20)),
                                            SizedBox(width: 6),
                                            IconButton(
                                              icon: Icon(Icons.add_circle,
                                                  color: Color(0xFF65558F)),
                                              iconSize: 30,
                                              onPressed: () => _updateQuantity(
                                                  product.id, 1),
                                            ),
                                          ],
                                        ),
                                )),
                          ],
                        )
                      : _selectedIndex == 1 &&
                              cartItems.isEmpty &&
                              !_checkoutComplete // Cart Page, with empty cart message if no items
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'Empty cart',
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black,
                                    ),
                                  ),
                                  SizedBox(height: 20),
                                  ElevatedButton(
                                    onPressed: () {
                                      _onItemTapped(
                                          0); // Go back to main page (index 0)
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Color(0xFF65558F),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(30),
                                      ),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 12.0, horizontal: 16.0),
                                      child: Text(
                                        'Go to shopping',
                                        style: TextStyle(
                                          fontSize: 18,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : _selectedIndex == 1 &&
                                  _checkoutComplete // Cart Page, with empty cart message if no items
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        'Success!',
                                        style: TextStyle(
                                          fontSize: 26,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black,
                                        ),
                                      ),
                                      SizedBox(height: 20),
                                      Text(
                                        'Thank you for shopping with us!',
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: Colors.black,
                                        ),
                                      ),
                                      SizedBox(height: 20),
                                      ElevatedButton(
                                        onPressed: () {
                                          setState(() {
                                            _checkoutComplete =
                                                false; // Reset checkout status when 'Shop again' is pressed
                                          });
                                          _onItemTapped(
                                              0); // Go back to main page (index 0)
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Color(0xFF65558F),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(30),
                                          ),
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 12.0, horizontal: 16.0),
                                          child: Text(
                                            'Shop again',
                                            style: TextStyle(
                                              fontSize: 18,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : Column(
                                  children: [
                                    // Title bar with back arrow and "Cart" text
                                    Container(
                                      padding: EdgeInsets.all(4.0),
                                      child: Row(
                                        children: [
                                          IconButton(
                                            icon: Icon(Icons.arrow_back,
                                                color: Color(0xFF65558F)),
                                            onPressed: () {
                                              _onItemTapped(
                                                  0); // Go back to the previous screen
                                            },
                                          ),
                                          Text(
                                            'Cart',
                                            style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.black),
                                          ),
                                        ],
                                      ),
                                    ),

                                    // Scrollable list of cart items
                                    Expanded(
                                      child: SingleChildScrollView(
                                        child: Column(
                                          children: [
                                            // Iterate over cartItems, but only include items with quantities greater than 0
                                            ...cartItems
                                                .where((product) =>
                                                    productQuantities[
                                                            product.id] !=
                                                        null &&
                                                    productQuantities[
                                                            product.id]! >
                                                        0)
                                                .map((product) {
                                              return Dismissible(
                                                key: ValueKey(product
                                                    .id), // Unique key for each item
                                                direction: DismissDirection
                                                    .endToStart, // Allow swiping from right to left
                                                onDismissed: (direction) {
                                                  setState(() {
                                                    // Remove item from the quantities map and cartItems list
                                                    productQuantities
                                                        .remove(product.id);
                                                    cartItems.removeWhere(
                                                        (item) =>
                                                            item.id ==
                                                            product.id);
                                                  });

                                                  // Show confirmation snackbar
                                                  ScaffoldMessenger.of(context)
                                                      .showSnackBar(
                                                    SnackBar(
                                                        content: Text(
                                                            '${product.name} removed from cart')),
                                                  );
                                                },
                                                background: Container(
                                                  color: Colors
                                                      .red, // Red background when swiping
                                                  alignment:
                                                      Alignment.centerRight,
                                                  padding: EdgeInsets.only(
                                                      right: 20),
                                                  child: Icon(Icons.delete,
                                                      color: Colors.white,
                                                      size: 30), // Delete icon
                                                ),
                                                child: ListTile(
                                                  leading: Container(
                                                    width: 60,
                                                    height: 60,
                                                    decoration: BoxDecoration(
                                                      color: Colors.grey,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              12),
                                                    ),
                                                  ),
                                                  title: Text(
                                                    product.name,
                                                    style: TextStyle(
                                                      fontSize: 18,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: Color(0xFF65558F),
                                                    ),
                                                  ),
                                                  subtitle: RichText(
                                                    text: TextSpan(
                                                      children: [
                                                        TextSpan(
                                                          text: NumberFormat(
                                                                  "#,###.00")
                                                              .format(product
                                                                  .price),
                                                          style: TextStyle(
                                                            fontSize: 18,
                                                            color: Color(
                                                                0xFF65558F),
                                                          ),
                                                        ),
                                                        TextSpan(
                                                          text: '/ unit',
                                                          style: TextStyle(
                                                            fontSize: 12,
                                                            color: Colors.grey,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  trailing: Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      IconButton(
                                                        icon: Icon(
                                                            Icons.remove_circle,
                                                            color: Color(
                                                                0xFF65558F)),
                                                        iconSize: 30,
                                                        onPressed: () =>
                                                            _updateQuantity(
                                                                product.id, -1),
                                                      ),
                                                      SizedBox(width: 6),
                                                      Text(
                                                        productQuantities[
                                                                product.id]
                                                            .toString(),
                                                        style: TextStyle(
                                                            fontSize: 20),
                                                      ),
                                                      SizedBox(width: 6),
                                                      IconButton(
                                                        icon: Icon(
                                                            Icons.add_circle,
                                                            color: Color(
                                                                0xFF65558F)),
                                                        iconSize: 30,
                                                        onPressed: () =>
                                                            _updateQuantity(
                                                                product.id, 1),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              );
                                            }),
                                          ],
                                        ),
                                      ),
                                    ),

                                    // Bottom Calculation Detail Section
                                    Container(
                                      color: Color.fromARGB(255, 238, 230, 255),
                                      padding: const EdgeInsets.all(16.0),
                                      child: Column(
                                        children: [
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text('Subtotal',
                                                  style: TextStyle(
                                                      fontSize: 18,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color:
                                                          Color(0xFF65558F))),
                                              Text(
                                                NumberFormat("#,###.00").format(
                                                    calculateSubtotalWithoutDiscount()),
                                                // NumberFormat("#,###.00").format(product.price)
                                                style: TextStyle(
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.bold,
                                                    color: Color(0xFF65558F)),
                                              ),
                                            ],
                                          ),
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text('Promotion discount',
                                                  style: TextStyle(
                                                      fontSize: 18,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color:
                                                          Color(0xFF65558F))),
                                              Text(
                                                '-${calculateDiscountForAllItems().toStringAsFixed(2)}',
                                                style: TextStyle(
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.red),
                                              ),
                                            ],
                                          ),
                                          SizedBox(height: 16),
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                NumberFormat("#,###.00").format(
                                                    calculateSubtotal()),
                                                // NumberFormat("#,###.00").format(product.price)
                                                style: TextStyle(
                                                    fontSize: 24,
                                                    fontWeight: FontWeight.bold,
                                                    color: Color(0xFF65558F)),
                                              ),
                                              ElevatedButton(
                                                onPressed: _completeCheckout,
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor:
                                                      Color(0xFF65558F),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            30),
                                                  ),
                                                ),
                                                child: Padding(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      vertical: 12.0,
                                                      horizontal: 16.0),
                                                  child: Text(
                                                    'Checkout',
                                                    style: TextStyle(
                                                      fontSize: 18,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
        ),

        //Navbar
        bottomNavigationBar: _selectedIndex == 0
            ? BottomNavigationBar(
                currentIndex: _selectedIndex,
                onTap: _onItemTapped,
                items: const [
                  BottomNavigationBarItem(
                    icon: Icon(Icons.shopping_basket),
                    label: 'Shopping',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.shopping_cart),
                    label: 'Cart',
                  ),
                ],
              )
            : null);
  }
}
