import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import 'connectivity_service.dart';

/// `true` = online. Provided app-wide so any page can
/// `context.watch<ConnectivityCubit>().state` to disable actions offline.
class ConnectivityCubit extends Cubit<bool> {
  ConnectivityCubit(ConnectivityService service) : super(service.isOnline) {
    _subscription = service.onStatusChanged.listen(emit);
  }

  late final StreamSubscription<bool> _subscription;

  @override
  Future<void> close() async {
    await _subscription.cancel();
    return super.close();
  }
}
