import 'package:equatable/equatable.dart';
import 'package:image_picker/image_picker.dart';

sealed class EditCampaignEvent extends Equatable {
  const EditCampaignEvent();

  @override
  List<Object?> get props => [];
}

final class EditCampaignStarted extends EditCampaignEvent {
  final int id;

  const EditCampaignStarted(this.id);

  @override
  List<Object?> get props => [id];
}

final class EditCampaignSubmitted extends EditCampaignEvent {
  final int id;
  final String? title;
  final String? description;
  final double? targetAmount;
  final XFile? image;

  const EditCampaignSubmitted({
    required this.id,
    this.title,
    this.description,
    this.targetAmount,
    this.image,
  });

  @override
  List<Object?> get props =>
      [id, title, description, targetAmount, image?.path];
}