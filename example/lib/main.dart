import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:synq_manager/synq_manager.dart';
import 'package:synq_manager_example/screens/login_screen.dart';
import 'package:synq_manager_example/screens/notes_screen.dart';
import 'package:synq_manager_example/services/sync_service.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SyncService()),
      ],
      child: MaterialApp(
        title: 'SynQ Manager Example',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          useMaterial3: true,
        ),
        home: const AppHome(),
      ),
    );
  }
}

class AppHome extends StatefulWidget {
  const AppHome({super.key});

  @override
  State<AppHome> createState() => _AppHomeState();
}

class _AppHomeState extends State<AppHome> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SyncService>().initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SyncService>(
      builder: (context, syncService, child) {
        if (!syncService.isInitialized) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        return StreamBuilder<AuthState>(
          stream: syncService.authStateChanges,
          builder: (context, snapshot) {
            final authState = snapshot.data;

            if (authState == null ||
                (!authState.isAuthenticated && !authState.isGuest)) {
              return const LoginScreen();
            }

            return const NotesScreen();
          },
        );
      },
    );
  }
}
