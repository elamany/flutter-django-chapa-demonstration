import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'app.dart';
import 'features/auth/bloc/auth_bloc.dart';
import 'features/auth/bloc/auth_event.dart';

void main() {

  runApp(
    
    BlocProvider(
      create: (_) => AuthBloc()..add(const AuthStarted()),
      child: const ChapaApp(),
    ),
  );
}