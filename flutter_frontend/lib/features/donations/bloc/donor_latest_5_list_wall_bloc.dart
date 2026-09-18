import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/api/api_exception.dart';
import '../data/repositories/donation_repository.dart';
import 'donorr_latest_5_list_wall_event.dart';
import 'donorr_latest_5_list_wall_state.dart';

class DonorWallBloc extends Bloc<DonorWallEvent, DonorWallState> {
  DonorWallBloc({DonationRepository? repository})
      : _repository = repository ?? DonationRepository(),
        super(const DonorWallInitial()) {
    on<DonorWallStarted>(_onStarted);
    on<DonorWallRefreshed>(_onRefreshed);
  }

  final DonationRepository _repository;

  int? _campaignId;

  Future<void> _onStarted(
    DonorWallStarted event,
    Emitter<DonorWallState> emit,
  ) async {
    _campaignId = event.campaignId;
    emit(const DonorWallLoading());
    await _fetch(emit);
  }

  Future<void> _onRefreshed(
    DonorWallRefreshed event,
    Emitter<DonorWallState> emit,
  ) async {
    final id = _campaignId;
    if (id == null) return;
    // Don't emit Loading — keep the existing list on screen while
    // refreshing, same UX as pull-to-refresh on the list below.
    await _fetch(emit);
  }

  Future<void> _fetch(Emitter<DonorWallState> emit) async {
    final id = _campaignId;
    if (id == null) return;

    try {
      final page = await _repository.listPublicDonations(
        campaignId: id,
        page: 1,
      );
      final preview = page.results.take(5).toList();
      emit(DonorWallLoaded(preview));
    } on ApiException catch (e) {
      emit(DonorWallFailure(e.message));
    }
  }
}