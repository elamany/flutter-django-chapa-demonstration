import 'package:equatable/equatable.dart';

import '../data/models/donation_initiation.dart'; 

sealed class DonateState extends Equatable {
  const DonateState();

  @override
  List<Object?> get props => [];
}

/// Idle — sheet is open and waiting for input.
final class DonateIdle extends DonateState {
  const DonateIdle();
}

/// Request in flight.
final class DonateLoading extends DonateState {
  const DonateLoading();
}

/// Server accepted the donation and returned a checkout URL.
final class DonateSuccess extends DonateState {
  final DonationInitiation initiation;

  const DonateSuccess(this.initiation);

  @override
  List<Object?> get props => [initiation];
}

/// Something went wrong — show the message in the sheet.
final class DonateFailure extends DonateState {
  final String message;

  const DonateFailure(this.message);

  @override
  List<Object?> get props => [message];
}