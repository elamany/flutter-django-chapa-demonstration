import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/widgets/shimmer_box.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../auth/bloc/auth_state.dart';
import '../../main/sign_in_prompt.dart';
import '../bloc/my_campaigns_bloc.dart';
import '../bloc/my_campaigns_event.dart';
import '../bloc/my_campaigns_state.dart';
import '../data/models/campaign.dart';
import '../widgets/my_campaign_card.dart';
import 'my_campaign_detail_screen.dart';

class MyCampaignsScreen extends StatelessWidget {
  const MyCampaignsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        if (state is! AuthAuthenticated) {
          return const SignInPrompt(
            title: 'My Campaigns',
            message: 'Sign in to create and manage your campaigns.',
            icon: Icons.dashboard_outlined,
          );
        }

        return BlocProvider(
          create: (_) => MyCampaignsBloc()..add(const MyCampaignsStarted()),
          child: const _MyCampaignsView(),
        );
      },
    );
  }
}

// Tabs definition
const _tabs = <({String label, String? status})>[
  (label: 'All', status: null),
  (label: 'Drafts', status: 'DRAFT'),
  (label: 'Review', status: 'PENDING_REVIEW'),
  (label: 'Active', status: 'ACTIVE'),
  (label: 'Completed', status: 'COMPLETED'),
  (label: 'Rejected', status: 'REJECTED'),
];

// View
class _MyCampaignsView extends StatefulWidget {
  const _MyCampaignsView();

  @override
  State<_MyCampaignsView> createState() => _MyCampaignsViewState();
}

class _MyCampaignsViewState extends State<_MyCampaignsView>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();

    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(_onTabChanged);
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    context
        .read<MyCampaignsBloc>()
        .add(MyCampaignsStatusChanged(_tabs[_tabController.index].status));
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 300) {
      context.read<MyCampaignsBloc>().add(const MyCampaignsLoadMore());
    }
  }

  Future<void> _refresh() async {
    context.read<MyCampaignsBloc>().add(const MyCampaignsRefreshed());
    await Future.delayed(const Duration(milliseconds: 400));
  }

  void _openCampaign(Campaign campaign) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MyCampaignDetailScreen(campaignId: campaign.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Campaigns'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: _tabs.map((t) => Tab(text: t.label)).toList(),
        ),
      ),
      body: BlocBuilder<MyCampaignsBloc, MyCampaignsState>(
        builder: (context, state) {
          return switch (state) {
            MyCampaignsInitial() || MyCampaignsLoading() =>
              const _MyCampaignsSkeleton(),
            MyCampaignsFailure() =>
              _FailureView(message: state.message, onRetry: _refresh),
            MyCampaignsLoaded() => _LoadedView(
                state: state,
                scrollController: _scrollController,
                onRefresh: _refresh,
                onOpen: _openCampaign,
              ),
          };
        },
      ),
    );
  }
}

// Loaded
class _LoadedView extends StatelessWidget {
  const _LoadedView({
    required this.state,
    required this.scrollController,
    required this.onRefresh,
    required this.onOpen,
  });

  final MyCampaignsLoaded state;
  final ScrollController scrollController;
  final Future<void> Function() onRefresh;
  final void Function(Campaign) onOpen;

  @override
  Widget build(BuildContext context) {
    if (state.campaigns.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 100),
            _EmptyState(),
          ],
        ),
      );
    }

    final itemCount = state.campaigns.length + 1;

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.builder(
        controller: scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        itemCount: itemCount,
        itemBuilder: (context, index) {
          if (index == state.campaigns.length) {
            return _Footer(state: state);
          }
          final campaign = state.campaigns[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: MyCampaignCard(
              campaign: campaign,
              onTap: () => onOpen(campaign),
            ),
          );
        },
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.state});

  final MyCampaignsLoaded state;

  @override
  Widget build(BuildContext context) {
    if (state.isLoadingMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: SizedBox(
            height: 24,
            width: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    if (!state.hasNext) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: Text('No more campaigns.')),
      );
    }
    return const SizedBox(height: 24);
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          Icon(
            Icons.campaign_outlined,
            size: 72,
            color: scheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            'No campaigns here',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Tap the + button below to start your first campaign.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

// Skeleton
class _MyCampaignsSkeleton extends StatelessWidget {
  const _MyCampaignsSkeleton();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ShimmerGroup(
      child: ListView.builder(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        itemCount: 5,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              height: 140,
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          );
        },
      ),
    );
  }
}

// Failure
class _FailureView extends StatelessWidget {
  const _FailureView({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.cloud_off_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: onRetry,
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}