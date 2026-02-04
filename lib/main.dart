import 'package:flutter/material.dart';
import 'package:equisplit/services/database_service.dart';
import 'package:equisplit/pages/login_page.dart';
import 'package:equisplit/pages/signup_page.dart';
import 'package:equisplit/pages/dashboard_page.dart';
import 'package:equisplit/pages/users_list_page.dart';
import 'package:equisplit/pages/profile_page.dart';
import 'package:equisplit/pages/settings_page.dart';
import 'package:equisplit/pages/create_expense_page.dart';
import 'package:equisplit/pages/expense_details_page.dart';
import 'package:equisplit/pages/transactions_page.dart';
import 'package:equisplit/pages/debug_page.dart';
import 'package:equisplit/pages/expenses_list_page.dart';
import 'package:equisplit/pages/messaging_page.dart';
import 'package:equisplit/pages/conversation_page.dart';
import 'package:equisplit/pages/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _isConnecting = true;

  @override
  void initState() {
    super.initState();
    _connectToDatabase();
  }

  Future<void> _connectToDatabase() async {
    try {
      await DatabaseService().connect();
      await Future.delayed(const Duration(seconds: 2)); // Show splash for at least 2 seconds
      if (mounted) {
        setState(() => _isConnecting = false);
      }
    } catch (e) {
      print('Database connection error: $e');
      if (mounted) {
        setState(() => _isConnecting = false);
      }
    }
  }

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    if (_isConnecting) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: SplashScreen(),
      );
    }

    return MaterialApp(
      title: 'EquiSplit',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1976D2)),
        scaffoldBackgroundColor: const Color(0xFFF8FAFF),
      ),
      home: const LoginPage(),
      routes: {
        '/login': (context) => const LoginPage(),
        '/signup': (context) => const SignUpPage(),
        '/dashboard': (context) {
          final user = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
          return DashboardPage(user: user);
        },
        '/users': (context) {
          final user = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
          return UsersListPage(currentUser: user);
        },
        '/profile': (context) {
          final arguments = ModalRoute.of(context)?.settings.arguments;
          
          // Handle both old format (single user) and new format (with currentUser)
          if (arguments is Map<String, dynamic>) {
            return ProfilePage(
              user: arguments['user'] as Map<String, dynamic>?,
              currentUser: arguments['currentUser'] as Map<String, dynamic>?,
            );
          } else if (arguments is Map<String, dynamic>) {
            // Old format: just user
            return ProfilePage(user: arguments);
          } else {
            return const ProfilePage();
          }
        },
        '/settings': (context) {
          final user = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
          return SettingsPage(currentUser: user);
        },
        '/create-expense': (context) {
          final user = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
          return CreateExpensePage(currentUser: user);
        },
        '/expense-details': (context) {
          final arguments = ModalRoute.of(context)?.settings.arguments;
          int expenseId = 0;
          Map<String, dynamic>? currentUser;
          
          if (arguments is int) {
            expenseId = arguments;
          } else if (arguments is Map<String, dynamic>) {
            expenseId = arguments['expense_id'] as int? ?? 0;
            currentUser = arguments['current_user'] as Map<String, dynamic>?;
          }
          
          return ExpenseDetailsPage(expenseId: expenseId, currentUser: currentUser);
        },
        '/transactions': (context) {
          final user = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
          return TransactionsPage(currentUser: user ?? {});
        },
        '/expenses': (context) {
          final user = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
          return ExpensesListPage(user: user);
        },
        '/messages': (context) {
          final user = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
          return MessagingPage(currentUser: user);
        },
        '/conversation': (context) {
          final arguments = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
          return ConversationPage(
            otherUser: arguments?['otherUser'] as Map<String, dynamic>? ?? {},
            currentUser: arguments?['currentUser'] as Map<String, dynamic>?,
          );
        },
        '/debug': (context) => const DebugPage(),
      },
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;

  void _incrementCounter() {
    setState(() {
      // This call to setState tells the Flutter framework that something has
      // changed in this State, which causes it to rerun the build method below
      // so that the display can reflect the updated values. If we changed
      // _counter without calling setState(), then the build method would not be
      // called again, and so nothing would appear to happen.
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      appBar: AppBar(
        // TRY THIS: Try changing the color here to a specific color (to
        // Colors.amber, perhaps?) and trigger a hot reload to see the AppBar
        // change color while the other colors stay the same.
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
      ),
      body: Center(
        // Center is a layout widget. It takes a single child and positions it
        // in the middle of the parent.
        child: Column(
          // Column is also a layout widget. It takes a list of children and
          // arranges them vertically. By default, it sizes itself to fit its
          // children horizontally, and tries to be as tall as its parent.
          //
          // Column has various properties to control how it sizes itself and
          // how it positions its children. Here we use mainAxisAlignment to
          // center the children vertically; the main axis here is the vertical
          // axis because Columns are vertical (the cross axis would be
          // horizontal).
          //
          // TRY THIS: Invoke "debug painting" (choose the "Toggle Debug Paint"
          // action in the IDE, or press "p" in the console), to see the
          // wireframe for each widget.
          mainAxisAlignment: .center,
          children: [
            const Text('You have pushed the button this many times:'),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ),
    );
  }
}
