import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/challenge.dart';
import '../services/challenge_service.dart';
import '../services/gamification_service.dart';
import '../services/ad_service.dart';
import '../widgets/challenge_card.dart';
import '../widgets/scratch_reward_dialog.dart';

class ChallengesScreen extends StatefulWidget {
  const ChallengesScreen({super.key});

  @override
  State<ChallengesScreen> createState() => _ChallengesScreenState();
}

class _ChallengesScreenState extends State<ChallengesScreen> {
  WeeklyChallengeProgress? _progress;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final progress = await ChallengeService.instance.getProgress(uid);
    if (mounted) setState(() { _progress = progress; _loading = false; });
  }

  Future<void> _collectReward(ChallengeDefinition challenge) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    // Show a rewarded ad before granting the reward.
    // If the ad fails to load, proceed anyway so the user isn't blocked.
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Loading your reward — watch a short ad to claim it!'),
        duration: Duration(seconds: 2),
      ),
    );

    await AdService.instance.showRewarded(
      onEarnedReward: () {}, // reward is always granted below
      onFailed: () {},       // fail-open: proceed even if ad fails
    );

    if (!mounted) return;

    final weekNum = ChallengeService.currentWeekNumber();
    final reward = ChallengeService.rewardFor(challenge.id, weekNum);

    final collected = await showScratchRewardDialog(
      context,
      challengeTitle: challenge.title,
      reward: reward,
    );

    if (!collected || !mounted) return;

    // Mark as collected
    await ChallengeService.instance.collectReward(uid, challenge.id);

    // Apply reward
    if (reward.type == RewardType.xp) {
      await GamificationService.instance.awardXP(uid, reward.value);
    } else if (reward.type == RewardType.shield) {
      await GamificationService.instance.addShield(uid, reward.value);
    }

    // Refresh
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final active = ChallengeService.instance.getActiveChallenges();
    final daysLeft = ChallengeService.daysUntilReset();

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Weekly Challenges'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                'Resets in $daysLeft day${daysLeft == 1 ? '' : 's'}',
                style: const TextStyle(
                    color: Colors.white54, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.deepPurpleAccent))
          : SafeArea(
              child: ListView.separated(
                padding: const EdgeInsets.all(24),
                itemCount: active.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (_, i) {
                  final challenge = active[i];
                  final prog = _progress!;
                  return ChallengeCard(
                    challenge: challenge,
                    currentProgress: prog.getProgress(challenge.id),
                    isCompleted: prog.isCompleted(challenge.id),
                    isCollected: prog.isCollected(challenge.id),
                    onCollect: prog.isCompleted(challenge.id) &&
                            !prog.isCollected(challenge.id)
                        ? () => _collectReward(challenge)
                        : null,
                  );
                },
              ),
            ),
    );
  }
}
