import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/widgets/shimmer_box.dart';
import '../bloc/campaign_list_bloc.dart';
import '../bloc/campaign_list_event.dart';
import '../bloc/campaign_list_state.dart';
import '../widgets/campaign_card.dart';
import '../widgets/campaign_card_skeleton.dart';
import '../widgets/home_hero.dart';
import 'campaign_detail_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.onProfileTap,
  });

  final VoidCallback onProfileTap;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => CampaignListBloc()..add(const CampaignListStarted()),
      child: _HomeView(onProfileTap: onProfileTap),
    );
  }
}

class _HomeView extends StatefulWidget {
  const _HomeView({required this.onProfileTap});

  final VoidCallback onProfileTap;

  @override
  State<_HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<_HomeView> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 400) {
      context.read<CampaignListBloc>().add(const CampaignListLoadMore());
    }
  }

  Future<void> _refresh() async {
    context.read<CampaignListBloc>().add(const CampaignListRefreshed());
    await Future.delayed(const Duration(milliseconds: 400));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: BlocBuilder<CampaignListBloc, CampaignListState>(
          builder: (context, state) {
            return CustomScrollView(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: HomeHero(onProfileTap: widget.onProfileTap),
                ),

                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Campaigns',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 24,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ),
                ),

                SliverPersistentHeader(
                  pinned: true,
                  delegate: _FilterChipsHeaderDelegate(
                    topInset: MediaQuery.of(context).padding.top,
                  ),
                ),

                // Content — loading / failure / list.
                ..._contentSlivers(state),
              ],
            );
          },
        ),
      ),
    );
  }

  // Content per state
  List<Widget> _contentSlivers(CampaignListState state) {
    switch (state) {
      case CampaignListInitial():
      case CampaignListLoading():
        return const [_SkeletonSliver()];

      case CampaignListFailure():
        return [
          SliverFillRemaining(
            hasScrollBody: false,
            child: _FailureView(message: state.message),
          ),
        ];

      case CampaignListLoaded():
        return _loadedSlivers(state);
    }
  }

  List<Widget> _loadedSlivers(CampaignListLoaded state) {
    if (state.campaigns.isEmpty) {
      return const [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(child: Text('No campaigns yet.')),
        ),
      ];
    }

    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        sliver: SliverList.builder(
          itemCount: state.campaigns.length,
          itemBuilder: (context, index) {
            final campaign = state.campaigns[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: CampaignCard(
                campaign: campaign,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          CampaignDetailScreen(campaignId: campaign.id),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
      SliverToBoxAdapter(child: _Footer(state: state)),
    ];
  }
}

// Sticky filter chips
class _FilterChipsHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _FilterChipsHeaderDelegate({required this.topInset});

  final double topInset;

  static const double _chipsHeight = 56;

  @override
  double get minExtent => _chipsHeight + topInset;

  @override
  double get maxExtent => _chipsHeight + topInset;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final scheme = Theme.of(context).colorScheme;

    // Strong blue gradient (same spirit as HomeHero)
    final Color topColor = scheme.primary;
    final Color bottomColor = Color.lerp(
      scheme.primary,
      scheme.primaryContainer,
      0.55,
    )!;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            // Always show gradient when sticky
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: overlapsContent
                  ? [
                      topColor.withValues(alpha: 0.97),
                      bottomColor.withValues(alpha: 0.97),
                    ]
                  : [
                      scheme.surface.withValues(alpha: 0.85),
                      scheme.surface.withValues(alpha: 0.85),
                    ],
            ),
            boxShadow: overlapsContent
                ? [
                    BoxShadow(
                      color: topColor.withValues(alpha: 0.35),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: Column(
            children: [
              SizedBox(height: topInset),
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _FilterChips(
                    forceLightStyle: overlapsContent, // white chips on blue
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _FilterChipsHeaderDelegate old) =>
      old.topInset != topInset;
}

class _FilterChips extends StatelessWidget {
  const _FilterChips({this.forceLightStyle = false});

  final bool forceLightStyle;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CampaignListBloc, CampaignListState>(
      buildWhen: (prev, curr) {
        final prevFilter =
            prev is CampaignListLoaded ? prev.statusFilter : null;
        final currFilter =
            curr is CampaignListLoaded ? curr.statusFilter : null;
        return prevFilter != currFilter;
      },
      builder: (context, state) {
        final current = state is CampaignListLoaded ? state.statusFilter : null;

        return SizedBox(
          width: double.infinity,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                _Chip(
                  label: 'All',
                  selected: current == null,
                  forceLightStyle: forceLightStyle,
                  onSelected: () => context
                      .read<CampaignListBloc>()
                      .add(const CampaignListFilterChanged(null)),
                ),
                const SizedBox(width: 8),
                _Chip(
                  label: 'Active',
                  selected: current == 'ACTIVE',
                  forceLightStyle: forceLightStyle,
                  onSelected: () => context
                      .read<CampaignListBloc>()
                      .add(const CampaignListFilterChanged('ACTIVE')),
                ),
                const SizedBox(width: 8),
                _Chip(
                  label: 'Completed',
                  selected: current == 'COMPLETED',
                  forceLightStyle: forceLightStyle,
                  onSelected: () => context
                      .read<CampaignListBloc>()
                      .add(const CampaignListFilterChanged('COMPLETED')),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onSelected,
    this.forceLightStyle = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;
  final bool forceLightStyle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          color: forceLightStyle
              ? (selected ? scheme.primary : Colors.white)
              : null,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
        ),
      ),
      selected: selected,
      onSelected: (_) => onSelected(),
      selectedColor: forceLightStyle ? Colors.white : null,
      backgroundColor: forceLightStyle
          ? Colors.white.withValues(alpha: 0.18)
          : null,
      side: forceLightStyle
          ? BorderSide(color: Colors.white.withValues(alpha: 0.35))
          : null,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );
  }
}

// Skeleton sliver
class _SkeletonSliver extends StatelessWidget {
  const _SkeletonSliver();

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      sliver: SliverToBoxAdapter(
        child: ShimmerGroup(
          child: Column(
            children: List.generate(
              4,
              (_) => const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: CampaignCardSkeleton(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Footer
class _Footer extends StatelessWidget {
  const _Footer({required this.state});

  final CampaignListLoaded state;

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

// Failure
class _FailureView extends StatelessWidget {
  const _FailureView({required this.message});

  final String message;

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
              onPressed: () {
                context
                    .read<CampaignListBloc>()
                    .add(const CampaignListStarted());
              },
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}