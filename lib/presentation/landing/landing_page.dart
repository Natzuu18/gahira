import 'package:flutter/material.dart';

import '../../main.dart';
import '../shared_widgets/appColor.dart';
import '../shared_widgets/themeToggleButton.dart';
import 'mining_background.dart';
import 'register_form_section.dart';

class LandingPage extends StatefulWidget {
  const LandingPage({super.key});

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  final _homeKey = GlobalKey();
  final _overviewKey = GlobalKey();
  final _workflowKey = GlobalKey();
  final _rolesKey = GlobalKey();

  void _goToLogin() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
    );
  }

  void _goToRegister() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: context.bgColor,
          appBar: AppBar(
            title: const Text('Apply to Gahira'),
            leading: IconButton(
              tooltip: 'Back to home',
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          body: const SafeArea(
            child: SingleChildScrollView(child: RegisterFormSection()),
          ),
        ),
      ),
    );
  }

  Future<void> _scrollTo(GlobalKey key) async {
    final targetContext = key.currentContext;
    if (targetContext == null) return;
    await Scrollable.ensureVisible(
      targetContext,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeInOutCubic,
      alignment: 0.04,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 760;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: kGold.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(9),
              ),
              child: const Icon(
                Icons.settings_input_component_rounded,
                color: kGold,
                size: 19,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'GAHIRA',
              style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 1.5),
            ),
          ],
        ),
        actions: [
          if (isWide) ...[
            _navButton('Home', _homeKey),
            _navButton('Overview', _overviewKey),
            _navButton('How it works', _workflowKey),
            _navButton('Who it serves', _rolesKey),
          ] else
            PopupMenuButton<String>(
              tooltip: 'Navigate',
              onSelected: (value) {
                final key = switch (value) {
                  'Home' => _homeKey,
                  'Overview' => _overviewKey,
                  'How it works' => _workflowKey,
                  _ => _rolesKey,
                };
                _scrollTo(key);
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'Home', child: Text('Home')),
                PopupMenuItem(value: 'Overview', child: Text('Overview')),
                PopupMenuItem(
                  value: 'How it works',
                  child: Text('How it works'),
                ),
                PopupMenuItem(
                  value: 'Who it serves',
                  child: Text('Who it serves'),
                ),
              ],
            ),
          const ThemeToggleButton(),
          Padding(
            padding: const EdgeInsets.only(left: 4, right: 16),
            child: isWide
                ? OutlinedButton.icon(
                    onPressed: _goToLogin,
                    icon: const Icon(Icons.login_rounded, size: 17),
                    label: const Text('Sign in'),
                  )
                : IconButton(
                    tooltip: 'Sign in',
                    onPressed: _goToLogin,
                    icon: const Icon(Icons.login_rounded),
                  ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildHero(context, isWide),
            _buildOverview(context),
            _buildWorkflow(context),
            _buildRoles(context),
            _buildClosingSection(context),
            _buildFooter(context),
          ],
        ),
      ),
    );
  }

  Widget _navButton(String label, GlobalKey key) {
    return TextButton(onPressed: () => _scrollTo(key), child: Text(label));
  }

  Widget _buildHero(BuildContext context, bool isWide) {
    return Container(
      key: _homeKey,
      width: double.infinity,
      color: kBlackSoft,
      child: Stack(
        children: [
          const Positioned.fill(
            child: MiningBackground(iconCount: 15, opacity: 0.12),
          ),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1120),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isWide ? 48 : 24,
                  vertical: isWide ? 88 : 64,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.2),
                        ),
                      ),
                      child: const Text(
                        'BALL MILL OPERATIONS',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.4,
                        ),
                      ),
                    ),
                    const SizedBox(height: 26),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 790),
                      child: Text(
                        'Gahira Ball Mill\nManagement System',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: isWide ? 54 : 38,
                          height: 1.08,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 620),
                      child: Text(
                        'Bring service requests, processing progress, equipment, and billing into one clear workspace for your mining operation.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.84),
                          fontSize: isWide ? 18 : 16,
                          height: 1.55,
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        FilledButton.icon(
                          onPressed: _goToRegister,
                          style: FilledButton.styleFrom(
                            backgroundColor: kGold,
                            foregroundColor: kBlack,
                            minimumSize: const Size(176, 50),
                          ),
                          icon: const Icon(Icons.arrow_forward_rounded),
                          label: const Text('Start an application'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => _scrollTo(_workflowKey),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: BorderSide(
                              color: Colors.white.withValues(alpha: 0.55),
                            ),
                            minimumSize: const Size(150, 50),
                          ),
                          icon: const Icon(Icons.account_tree_outlined),
                          label: const Text('See the workflow'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 52),
                    _buildHeroFlow(isWide),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroFlow(bool isWide) {
    final items = [
      ('01', 'Submit a request'),
      ('02', 'Verify material'),
      ('03', 'Track processing'),
      ('04', 'Settle the bill'),
    ];

    return Wrap(
      spacing: isWide ? 32 : 20,
      runSpacing: 16,
      children: items
          .map(
            (item) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  item.$1,
                  style: const TextStyle(
                    color: Color(0xFFE0C783),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 9),
                Text(
                  item.$2,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
              ],
            ),
          )
          .toList(),
    );
  }

  Widget _buildOverview(BuildContext context) {
    return _section(
      key: _overviewKey,
      background: context.bgColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeading(
            eyebrow: 'ONE CONNECTED WORKSPACE',
            title: 'The work, from request to settlement.',
            description:
                'Gahira organizes the steps around ball mill service so each person can see what needs attention and what happens next.',
          ),
          const SizedBox(height: 34),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 760 ? 3 : 1;
              final width = columns == 1
                  ? constraints.maxWidth
                  : (constraints.maxWidth - 40) / 3;
              return Wrap(
                spacing: 20,
                runSpacing: 20,
                children: [
                  _overviewItem(
                    width,
                    icon: Icons.description_outlined,
                    title: 'Service requests',
                    text:
                        'Submit material details, follow review status, and respond when a request needs attention.',
                  ),
                  _overviewItem(
                    width,
                    icon: Icons.precision_manufacturing_outlined,
                    title: 'Processing operations',
                    text:
                        'Coordinate verification, scheduling, equipment, and job progress in the operational workflow.',
                  ),
                  _overviewItem(
                    width,
                    icon: Icons.receipt_long_outlined,
                    title: 'Billing and records',
                    text:
                        'Prepare financial handling, record cash payments, and review transaction history.',
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _overviewItem(
    double width, {
    required IconData icon,
    required String title,
    required String text,
  }) {
    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: kGold, size: 25),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              text,
              style: TextStyle(color: context.mutedTextColor, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkflow(BuildContext context) {
    final steps = [
      (
        '01',
        'Apply or sign in',
        'Choose the account type that matches your role.',
      ),
      (
        '02',
        'Create a service request',
        'Provide material details and any required supporting information.',
      ),
      (
        '03',
        'Review and process',
        'Operators verify the request before scheduling and processing work.',
      ),
      (
        '04',
        'Review the outcome',
        'Follow status updates and complete financial handling and payment.',
      ),
    ];

    return _section(
      key: _workflowKey,
      background: context.surfaceColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeading(
            eyebrow: 'HOW IT WORKS',
            title: 'A straightforward path through the operation.',
            description:
                'Each stage has a clear owner and status, from the first request through final billing.',
          ),
          const SizedBox(height: 30),
          ...steps.map(
            (step) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 13),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 48,
                    child: Text(
                      step.$1,
                      style: const TextStyle(
                        color: kGold,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          step.$2,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          step.$3,
                          style: TextStyle(
                            color: context.mutedTextColor,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoles(BuildContext context) {
    return _section(
      key: _rolesKey,
      background: context.bgColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeading(
            eyebrow: 'BUILT FOR THE PEOPLE DOING THE WORK',
            title: 'One operation. Role-specific views.',
            description:
                'Gahira gives each account access to the tasks and records relevant to their work.',
          ),
          const SizedBox(height: 28),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _roleItem(
                context,
                icon: Icons.groups_outlined,
                title: 'Miners & clients',
                description:
                    'Submit service requests, follow verification and processing, and review billing and account records.',
              ),
              _roleItem(
                context,
                icon: Icons.engineering_outlined,
                title: 'Operators',
                description:
                    'Review service details and support verification and processing workflows.',
              ),
              _roleItem(
                context,
                icon: Icons.admin_panel_settings_outlined,
                title: 'Administrators',
                description:
                    'Manage approvals, schedules, equipment, billing, and operational records. Admin accounts are provided by the system administrator.',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _roleItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
  }) {
    return SizedBox(
      width: 250,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: kGold, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 5),
                Text(
                  description,
                  style: TextStyle(
                    color: context.mutedTextColor,
                    height: 1.45,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClosingSection(BuildContext context) {
    return Container(
      width: double.infinity,
      color: kBlackSoft,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1120),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 620;
                final copy = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Ready to use Gahira?',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 25,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Submit an account application or sign in to continue your work.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.82),
                        height: 1.45,
                      ),
                    ),
                  ],
                );
                final actions = Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    FilledButton(
                      onPressed: _goToRegister,
                      style: FilledButton.styleFrom(
                        backgroundColor: kGold,
                        foregroundColor: kBlack,
                      ),
                      child: const Text('Apply for an account'),
                    ),
                    TextButton(
                      onPressed: _goToLogin,
                      child: const Text(
                        'Sign in',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                );
                if (compact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [copy, const SizedBox(height: 22), actions],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: copy),
                    const SizedBox(width: 24),
                    actions,
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1120),
          child: Row(
            children: [
              const Icon(
                Icons.settings_input_component_rounded,
                color: kGold,
                size: 18,
              ),
              const SizedBox(width: 9),
              const Text(
                'GAHIRA',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  letterSpacing: 1,
                ),
              ),
              const Spacer(),
              Flexible(
                child: Text(
                  'Ball Mill Management System',
                  textAlign: TextAlign.end,
                  style: TextStyle(color: context.mutedTextColor, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _section({
    required GlobalKey key,
    required Color background,
    required Widget child,
  }) {
    return Container(
      key: key,
      width: double.infinity,
      color: background,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1120),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 54),
            child: child,
          ),
        ),
      ),
    );
  }

  Widget _sectionHeading({
    required String eyebrow,
    required String title,
    required String description,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          eyebrow,
          style: const TextStyle(
            color: kGold,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 11),
        Text(
          title,
          style: const TextStyle(
            fontSize: 26,
            height: 1.2,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: Text(
            description,
            style: TextStyle(color: context.mutedTextColor, height: 1.55),
          ),
        ),
      ],
    );
  }
}
