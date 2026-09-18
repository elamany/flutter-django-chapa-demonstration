import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/api/api_exception.dart';
import '../data/repositories/campaign_repository.dart';
import 'create_campaign_event.dart';
import 'create_campaign_state.dart';

class CreateCampaignBloc
    extends Bloc<CreateCampaignEvent, CreateCampaignState> {
  CreateCampaignBloc({CampaignRepository? repository})
      : _repository = repository ?? CampaignRepository(),
        super(const CreateCampaignIdle()) {
    on<CreateCampaignSubmitted>(_onSubmitted);
    on<CreateCampaignReset>(_onReset);
  }

  final CampaignRepository _repository;

  Future<void> _onSubmitted(
    CreateCampaignSubmitted event,
    Emitter<CreateCampaignState> emit,
  ) async {
    emit(const CreateCampaignLoading());

    try {
      final campaign = await _repository.createCampaign(
        title: event.title,
        description: event.description,
        targetAmount: event.targetAmount,
        image: event.image,
      );
      emit(CreateCampaignSuccess(campaign));
    } on ApiException catch (e) {
      emit(CreateCampaignFailure(e.message));
    }
  }

  void _onReset(
    CreateCampaignReset event,
    Emitter<CreateCampaignState> emit,
  ) {
    emit(const CreateCampaignIdle());
  }
}