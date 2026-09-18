import 'package:equatable/equatable.dart';

sealed class DonorWallEvent extends Equatable {
  const DonorWallEvent();

  @override
  List<Object?> get props => [];
}

final class DonorWallStarted extends DonorWallEvent {
  final int campaignId;

  const DonorWallStarted(this.campaignId);

  @override
  List<Object?> get props => [campaignId];
}

/// Re-fetch using the campaign id stored from the last [DonorWallStarted].
final class DonorWallRefreshed extends DonorWallEvent {
  const DonorWallRefreshed();
}