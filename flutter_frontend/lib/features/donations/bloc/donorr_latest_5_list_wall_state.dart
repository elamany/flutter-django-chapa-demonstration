import 'package:equatable/equatable.dart';

import '../data/models/donation.dart';

sealed class DonorWallState extends Equatable {
  const DonorWallState();

  @override
  List<Object?> get props => [];
}

final class DonorWallInitial extends DonorWallState {
  const DonorWallInitial();
}

final class DonorWallLoading extends DonorWallState {
  const DonorWallLoading();
}

final class DonorWallLoaded extends DonorWallState {
  final List<Donation> donations;

  const DonorWallLoaded(this.donations);

  @override
  List<Object?> get props => [donations];
}

final class DonorWallFailure extends DonorWallState {
  final String message;

  const DonorWallFailure(this.message);

  @override
  List<Object?> get props => [message];
}