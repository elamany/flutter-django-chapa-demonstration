import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/api/api_exception.dart';
import '../data/repositories/campaign_repository.dart';
import 'edit_campaign_event.dart';
import 'edit_campaign_state.dart';

class EditCampaignBloc extends Bloc<EditCampaignEvent, EditCampaignState> {
  EditCampaignBloc({CampaignRepository? repository})
      : _repository = repository ?? CampaignRepository(),
        super(const EditCampaignInitial()) {
    on<EditCampaignStarted>(_onStarted);
    on<EditCampaignSubmitted>(_onSubmitted);
  }

  final CampaignRepository _repository;

  Future<void> _onStarted(
    EditCampaignStarted event,
    Emitter<EditCampaignState> emit,
  ) async {
    emit(const EditCampaignLoading());
    try {
      final campaign = await _repository.myCampaignDetail(event.id);
      emit(EditCampaignReady(campaign));
    } on ApiException catch (e) {
      emit(EditCampaignFailure(e.message));
    }
  }

  Future<void> _onSubmitted(
    EditCampaignSubmitted event,
    Emitter<EditCampaignState> emit,
  ) async {
    final current = state;
    if (current is! EditCampaignReady) return;

    emit(current.copyWith(submitting: true));

    try {
      final updated = await _repository.updateCampaign(
        id: event.id,
        title: event.title,
        description: event.description,
        targetAmount: event.targetAmount,
        image: event.image,
      );
      emit(EditCampaignSuccess(updated));
    } on ApiException catch (e) {
      // Return to Ready so the user can fix and retry.
      emit(current.copyWith(submitting: false));
      
      emit(EditCampaignFailure(e.message));
    }
  }
}