import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/api/api_exception.dart';
import '../data/repositories/donation_repository.dart';
import 'donate_event.dart';
import 'donate_state.dart';

class DonateBloc extends Bloc<DonateEvent, DonateState> {
  DonateBloc({DonationRepository? repository})
      : _repository = repository ?? DonationRepository(),
        super(const DonateIdle()) {
    on<DonateSubmitted>(_onSubmitted);
    on<DonateReset>(_onReset);
  }

  final DonationRepository _repository;

  Future<void> _onSubmitted(
    DonateSubmitted event,
    Emitter<DonateState> emit,
  ) async {
    emit(const DonateLoading());

    try {
      final initiation = await _repository.initiateDonation(
        campaignId: event.campaignId,
        name: event.name,
        email: event.email,
        amount: event.amount,
        isAnonymous: event.isAnonymous,
      );
      emit(DonateSuccess(initiation));
    } on ApiException catch (e) {
      emit(DonateFailure(e.message));
    }
  }

  void _onReset(DonateReset event, Emitter<DonateState> emit) {
    emit(const DonateIdle());
  }
}