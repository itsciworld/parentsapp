import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vigil_parents_app/core/navigation/app_navigator.dart';
import 'package:vigil_parents_app/core/routing/routes.dart';
import 'package:vigil_parents_app/core/services/background/background_service.dart';
import 'package:vigil_parents_app/core/services/secure_storage/secure_storage.dart';

void main() async {
  final binding = WidgetsFlutterBinding.ensureInitialized();
  // Hold the native splash on screen through the async startup work below so
  // there is no blank frame between it and the first route.
  FlutterNativeSplash.preserve(widgetsBinding: binding);
  await dotenv.load(fileName: ".env");
  // Ensure existing sessions are mirrored to SharedPreferences so the
  // background isolate can read the auth token.
  await SecureDeviceService.syncMirrorFromSecure();
  await initializeBackgroundService();
  runApp(const ProviderScope(child: MyApp()));
  FlutterNativeSplash.remove();
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  final FlutterBackgroundService _service = FlutterBackgroundService();

  /// No background isolate on web — every `invoke` would throw there.
  void _notifyService(String event) {
    if (!backgroundServiceSupported) return;
    _service.invoke(event);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // App starts in the foreground — pause the background sync jobs so they
    // don't duplicate the on-screen polling. Re-send shortly after to win the
    // race against the background isolate finishing its event subscription.
    _notifyService('app_foreground');
    Future.delayed(
      const Duration(seconds: 2),
      () => _notifyService('app_foreground'),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _notifyService('app_foreground');
    } else {
      // paused / inactive / hidden / detached → let the background sync resume.
      _notifyService('app_background');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'Vigil Parents App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      initialRoute: AppRoutesName.splashView,
      // Build the initial stack with just the splash route. The default
      // behaviour splits '/splashView' into '/' + '/splashView', and the
      // phantom '/' resolves to the "Route not found" fallback that sits
      // hidden under every screen — pressing back to the root would surface it.
      onGenerateInitialRoutes: (_) => [
        AppRouteGenerator.generateRoute(
          const RouteSettings(name: AppRoutesName.splashView),
        ),
      ],
      onGenerateRoute: AppRouteGenerator.generateRoute,
    );
  }
}
