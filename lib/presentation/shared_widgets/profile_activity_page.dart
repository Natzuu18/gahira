import 'package:dartz/dartz.dart' hide State;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/error/failures.dart';
import '../../infrastructure/repositories/supabase_user_repository.dart';
import '../../infrastructure/supabase/supabase_config.dart';
import 'appColor.dart';
import 'themeToggleButton.dart';

class ProfileActivityPage extends StatefulWidget {
  const ProfileActivityPage({super.key, this.bottomNavigationBar});

  final Widget? bottomNavigationBar;
  @override
  State<ProfileActivityPage> createState() => _ProfileActivityPageState();
}

class _ProfileActivityPageState extends State<ProfileActivityPage> {
  final _repository = SupabaseUserRepository();
  String? _userId;
  late Future<Either<Failure, List<Map<String, dynamic>>>> _activityFuture;

  @override
  void initState() {
    super.initState();
    _userId = SupabaseConfig.client.auth.currentUser?.id;
    _activityFuture = _loadActivity();
  }

  Future<Either<Failure, List<Map<String, dynamic>>>> _loadActivity() {
    final userId = _userId;
    if (userId == null) {
      return Future.value(
        const Left(
          AuthFailure('You must be signed in to view profile activity.'),
        ),
      );
    }
    return _repository.getProfileActivity(userId);
  }

  Future<void> _refreshActivity() async {
    final future = _loadActivity();
    setState(() => _activityFuture = future);
    await future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bgColor,
      bottomNavigationBar: widget.bottomNavigationBar,
      appBar: AppBar(
        backgroundColor: context.surfaceColor,
        elevation: 0,
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_rounded, color: kGold),
        ),
        title: const Text(
          'PROFILE ACTIVITY',
          style: TextStyle(
            color: kGold,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
            fontSize: 15,
          ),
        ),
        iconTheme: const IconThemeData(color: kGold),
        actions: [
          IconButton(
            tooltip: 'Refresh activity',
            onPressed: _refreshActivity,
            icon: const Icon(Icons.refresh_rounded, color: kGold),
          ),
          const ThemeToggleButton(),
          const SizedBox(width: 8),
        ],
      ),
      body: FutureBuilder<Either<Failure, List<Map<String, dynamic>>>>(
        future: _activityFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: kGold));
          }
          final result = snapshot.data;
          if (result == null) {
            return _buildMessage(
              'Could not load profile activity. Pull down to try again.',
              isError: true,
            );
          }

          return result.fold(
            (failure) => _buildMessage(failure.message, isError: true),
            (activity) => RefreshIndicator(
              color: kGold,
              onRefresh: _refreshActivity,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Text(
                    'Recent profile updates',
                    style: TextStyle(
                      color: context.textColor,
                      fontSize: 21,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'See who changed your profile and when.',
                    style: TextStyle(color: context.mutedTextColor),
                  ),
                  const SizedBox(height: 18),
                  if (activity.isEmpty)
                    _buildMessage('No profile updates have been recorded yet.')
                  else
                    ...activity.map(_buildActivityCard),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildActivityCard(Map<String, dynamic> activity) {
    final rawFields = activity['changed_fields'];
    final fields = rawFields is List
        ? rawFields.map((field) => field.toString()).join(', ')
        : 'Profile information';
    final actorName = activity['updated_by_name']?.toString() ?? 'Unknown user';
    final actorRole = activity['updated_by_role']?.toString() ?? '';
    final timestamp = DateTime.tryParse(
      activity['created_at']?.toString() ?? '',
    );
    final formattedDate = timestamp == null
        ? 'Date unavailable'
        : DateFormat('MMM d, yyyy · h:mm a').format(timestamp.toLocal());

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kGold.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: kGold.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.edit_note_rounded, color: kGold),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Updated by $actorName${actorRole.isEmpty ? '' : ' · $actorRole'}',
                  style: TextStyle(
                    color: context.textColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Changed: $fields',
                  style: TextStyle(color: context.mutedTextColor, fontSize: 13),
                ),
                const SizedBox(height: 6),
                Text(
                  formattedDate,
                  style: TextStyle(color: context.mutedTextColor, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessage(String message, {bool isError = false}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isError ? Colors.redAccent : context.mutedTextColor,
          ),
        ),
      ),
    );
  }
}
