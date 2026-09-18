import 'package:equatable/equatable.dart';

sealed class DonateEvent extends Equatable {
  const DonateEvent();

  @override
  List<Object?> get props => [];
}

/// User submitted the donate form.
final class DonateSubmitted extends DonateEvent {
  final int campaignId;
  final String name;
  final String email;
  final double amount;
  final bool isAnonymous;

  const DonateSubmitted({
    required this.campaignId,
    required this.name,
    required this.email,
    required this.amount,
    required this.isAnonymous,
  });

  @override
  List<Object?> get props => [campaignId, name, email, amount, isAnonymous];
}


/// Clear the current state — called after the sheet closes so a fresh
/// open starts clean.
final class DonateReset extends DonateEvent {
  const DonateReset();
}