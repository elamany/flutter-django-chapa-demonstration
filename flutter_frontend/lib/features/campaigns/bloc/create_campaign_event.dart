import 'package:equatable/equatable.dart';
import 'package:image_picker/image_picker.dart';

sealed class CreateCampaignEvent extends Equatable {
  const CreateCampaignEvent();

  @override
  List<Object?> get props => [];
}

final class CreateCampaignSubmitted extends CreateCampaignEvent {
  final String title;
  final String description;
  final double targetAmount;
  final XFile? image;

  const CreateCampaignSubmitted({
    required this.title,
    required this.description,
    required this.targetAmount,
    required this.image,
  });

  @override
  List<Object?> get props => [title, description, targetAmount, image?.path];
}

final class CreateCampaignReset extends CreateCampaignEvent {
  const CreateCampaignReset();
}