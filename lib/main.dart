import 'package:class_attendance/firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'src/src.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const ClassAttendanceApp());
}

class ClassAttendanceApp extends StatelessWidget {
  const ClassAttendanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Repositórios concretos base
    final authRepo = FirebaseAuthRepository();                 // IAuthRepository
    final profilesRepo = FirestoreUserProfileRepository();     // IUserProfileRepository
    final peopleRepo = FirestorePeopleRepository();            // IPersonRepository
    final geoRepo = FirestoreGeoRepository();                  // IGeoRepository
    final accessRequestsRepo = FirestoreAccessRequestRepository(); // IAccessRequestRepository

    // 👇 instância ÚNICA e compartilhada, com profiles injetado (para escopo)
    final rehearsalRepo = FirestoreRehearsalRepository(
      profiles: profilesRepo,
      geo: geoRepo,
    ); // IRehearsalRepository

    final attendanceRepo = FirestoreAttendanceRepository();    // IAttendanceRepository
    final geoResolver = GeoNameResolver(geoRepo);

    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<IAuthRepository>.value(value: authRepo),
        RepositoryProvider<IUserProfileRepository>.value(value: profilesRepo),
        RepositoryProvider<IAccessRequestRepository>.value(value: accessRequestsRepo), // 👈 ADICIONADO
        RepositoryProvider<IPersonRepository>.value(value: peopleRepo),
        RepositoryProvider<IRehearsalRepository>.value(value: rehearsalRepo),
        RepositoryProvider<IAttendanceRepository>.value(value: attendanceRepo),
        RepositoryProvider<IEventReportRepository>(
          create: (_) => FirestoreEventReportRepository(),
        ),
        RepositoryProvider<IGeoRepository>.value(value: geoRepo),
        RepositoryProvider<GeoNameResolver>(
          create: (_) => geoResolver,
          lazy: false,
        ),
        RepositoryProvider<IRolesRepository>(
          create: (_) => FirestoreRolesRepository(),
        ),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (ctx) => AuthController(
              authRepo: ctx.read<IAuthRepository>(),
              profiles: ctx.read<IUserProfileRepository>(),
            ),
          ),
        ],
        child: _ScopeBinder(
          child: MaterialApp(
            title: 'Frequência ICM',
            theme: AppTheme.light(),
            locale: const Locale('pt', 'BR'),
            supportedLocales: const [
              Locale('pt', 'BR'),
              Locale('en'),
            ],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: const AuthGate(
              home: HomeView(),
              loginView: LoginView(),
            ),
          ),
        ),
      ),
    );
  }
}

/// Ouve o AuthController e injeta o escopo no mesmo repositório usado pelas telas.
class _ScopeBinder extends StatelessWidget {
  final Widget child;
  const _ScopeBinder({required this.child});

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthController, AuthState>(
      listenWhen: (p, c) => p.profile != c.profile,
      listener: (ctx, state) {
        final profile = state.profile;
        if (profile != null) {
          final repo = ctx.read<IRehearsalRepository>();
          // como setScope é específico da implementação, fazemos cast seguro
          if (repo is FirestoreRehearsalRepository) {
            repo.setScope(profile);
          }
        }
      },
      child: child,
    );
  }
}
