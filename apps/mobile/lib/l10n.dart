import 'package:flutter/widgets.dart';
import 'package:howl_core/howl_core.dart';

/// App text in Arabic (default) and English.
class S {
  S(this.lang);

  final String lang;
  bool get isAr => lang == 'ar';

  static S of(BuildContext context) =>
      S(Localizations.localeOf(context).languageCode == 'en' ? 'en' : 'ar');

  String t(String key, [Map<String, Object?> args = const {}]) {
    var s = (isAr ? _ar[key] : _en[key]) ?? _en[key] ?? key;
    for (final e in args.entries) {
      s = s.replaceAll('{${e.key}}', '${e.value}');
    }
    return s;
  }

  String role(Role r) => t('role.${r.name}');
  String roleDesc(Role r) => t('roleDesc.${r.name}');
  String team(Team team) => t('team.${team.name}');
  String phase(Phase p) => t('phase.${p.name}');
  String error(String code) => _en.containsKey('err.$code') ? t('err.$code') : t('err.unknown', {'code': code});

  String winner(String? w) => t('win.${w ?? 'none'}');

  /// The narrator's line for a game event.
  String event(GameEvent e, String Function(String? id) name) {
    final p = e.params;
    String r(Object? roleName) => roleName == null ? '' : role(Role.fromName(roleName as String));
    switch (e.type) {
      case Ev.gameStarted:
        return t('ev.gameStarted', {'n': p['players']});
      case Ev.roleAssigned:
        return t('ev.roleAssigned', {'role': r(p['role'])});
      case Ev.nightFalls:
        return t('ev.nightFalls', {'n': p['night']});
      case Ev.wolvesChose:
        return t('ev.wolvesChose', {'p': name(p['target'] as String?)});
      case Ev.seerResult:
        return t('ev.seerResult', {'p': name(p['target'] as String?), 'role': r(p['role'])});
      case Ev.witchTurn:
        return p['target'] == null ? t('ev.witchTurnNone') : t('ev.witchTurn', {'p': name(p['target'] as String?)});
      case Ev.dawn:
        return t('ev.dawn', {'n': p['night']});
      case Ev.killed:
        final who = name(p['player'] as String?);
        final cause = t('cause.${p['cause']}', {'p': who});
        return p['role'] == null ? cause : '$cause ${t('ev.wasRole', {'role': r(p['role'])})}';
      case Ev.noDeaths:
        return t('ev.noDeaths');
      case Ev.discussion:
        return t('ev.discussion', {'n': p['day']});
      case Ev.votingStarted:
        return t('ev.votingStarted');
      case Ev.votedOut:
        final line = t('ev.votedOut', {'p': name(p['player'] as String?), 'n': p['votes']});
        return p['role'] == null ? line : '$line ${t('ev.wasRole', {'role': r(p['role'])})}';
      case Ev.noElimination:
        return t(p['tie'] == true ? 'ev.tie' : 'ev.noVotes');
      case Ev.hunterTurn:
        return t('ev.hunterTurn', {'p': name(p['player'] as String?)});
      case Ev.hunterMissed:
        return t('ev.hunterMissed', {'p': name(p['player'] as String?)});
      case Ev.gameOver:
        return winner(p['winner'] as String?);
      case Ev.paused:
        return t('ev.paused');
      case Ev.resumed:
        return t('ev.resumed');
      case Ev.skipped:
        return t('ev.skipped');
    }
    return e.type;
  }

  /// The narrator's instruction for this player in the current phase.
  String guidance(GameView v) {
    final me = v.me;
    if (me.isNarrator) return t('guide.narrator');
    if (v.phase == Phase.lobby) return t(v.isHost ? 'guide.lobbyHost' : 'guide.lobby');
    if (v.phase == Phase.ended) return winner(v.winner);
    if (!me.alive) return t(v.currentHunter == me.id ? 'guide.hunter' : 'guide.dead');
    final role = me.role;
    switch (v.phase) {
      case Phase.night:
        switch (role?.nightAction) {
          case NightAction.wolfKill:
            return t('guide.night.wolf');
          case NightAction.inspect:
            return t(v.action == ActionKind.inspect ? 'guide.night.seer' : 'guide.night.seerDone');
          case NightAction.protect:
            return t('guide.night.guardian');
          case NightAction.witch:
            return t('guide.night.witchWait');
          default:
            return t('guide.night.sleep');
        }
      case Phase.witch:
        return t(role == Role.witch ? 'guide.witch' : 'guide.night.sleep');
      case Phase.day:
        return t('guide.day');
      case Phase.voting:
        return t(v.myChoice == null ? 'guide.voting' : 'guide.voted');
      case Phase.hunter:
        return t('guide.hunterWait', {'p': v.player(v.currentHunter ?? '')?.name ?? ''});
      default:
        return '';
    }
  }

  static const _en = <String, String>{
    'app': 'Moonhowl',
    'tagline': 'A night of wolves on your Wi-Fi',
    'host': 'Host a game',
    'join': 'Join a game',
    'rejoin': 'Rejoin last game',
    'profile': 'Profile',
    'editProfile': 'Edit profile',
    'name': 'Your name',
    'nameRequired': 'Pick a name first',
    'avatar': 'Avatar',
    'color': 'Color',
    'photo': 'Photo',
    'pickPhoto': 'Choose photo',
    'removePhoto': 'Remove photo',
    'save': 'Save',
    'cancel': 'Cancel',
    'ok': 'OK',
    'stats': 'Your stats',
    'gamesPlayed': 'Games',
    'wins': 'Wins',
    'winRate': 'Win rate',
    'favoriteRole': 'Most played',
    'language': 'Language',
    'sound': 'Sound',
    'vibration': 'Vibration',
    'settings': 'Settings',
    'roomName': 'Room name',
    'roomNameHint': '{name}\'s room',
    'passwordOptional': 'Password (optional)',
    'password': 'Password',
    'startHosting': 'Open room',
    'hostKeepOpen': 'Keep the app open while you host. Everyone plays through your phone.',
    'searching': 'Looking for rooms on this Wi-Fi…',
    'noRooms': 'No rooms found yet. Make sure you are on the same Wi-Fi as the host.',
    'scanQr': 'Scan QR code',
    'manual': 'Enter address',
    'address': 'Address (e.g. 192.168.1.5:47474)',
    'connect': 'Connect',
    'connecting': 'Connecting…',
    'reconnecting': 'Connection lost, reconnecting…',
    'checking': 'Checking room…',
    'roomNotFound': 'No room at that address.',
    'players': 'Players',
    'playersCount': '{n} players',
    'inGame': 'In game',
    'locked': 'Locked',
    'waitingHost': 'Waiting for the host to start…',
    'startGame': 'Start game',
    'roles': 'Roles',
    'autoRoles': 'Auto',
    'villagersFill': 'Villagers fill the rest: {n}',
    'rolesSummary': '{special} special roles for {players} players',
    'timers': 'Timers (seconds)',
    'timer.night': 'Night',
    'timer.witch': 'Witch',
    'timer.discussion': 'Discussion',
    'timer.voting': 'Voting',
    'timer.hunter': 'Hunter',
    'opt.narrator': 'I am the narrator (no role)',
    'opt.reveal': 'Reveal role on death',
    'opt.deadSee': 'Dead players see all roles',
    'opt.private': 'Allow private chats',
    'opt.publicVotes': 'Show who votes for whom',
    'lockRoom': 'Lock room',
    'kick': 'Remove',
    'kickConfirm': 'Remove {p} from the room?',
    'shareRoom': 'Players scan this or pick the room from the list',
    'youHost': 'Host',
    'narrator': 'Narrator',
    'you': 'You',
    'offline': 'Offline',
    'leave': 'Leave',
    'leaveConfirm': 'Leave this game?',
    'closeRoomConfirm': 'Close the room? Everyone will be disconnected.',
    'yourRole': 'Your role',
    'tapReveal': 'Tap to reveal your role',
    'tapHide': 'Tap to hide',
    'teamLabel': 'Team: {team}',
    'pause': 'Pause',
    'resume': 'Resume',
    'skip': 'Skip',
    'paused': 'Paused',
    'tab.game': 'Game',
    'tab.chat': 'Chat',
    'tab.log': 'Story',
    'chan.public': 'Village square',
    'chan.wolves': 'Wolf den',
    'chan.dead': 'Graveyard',
    'newDm': 'Private message',
    'newRoom': 'New group',
    'groupName': 'Group name',
    'members': 'Members',
    'create': 'Create',
    'leaveGroup': 'Leave group',
    'typeMessage': 'Message…',
    'chooseTarget': 'Choose a player',
    'confirm': 'Confirm',
    'vote': 'Vote',
    'skipVote': 'Skip vote',
    'youVotedSkip': 'You chose to skip',
    'votes': 'votes',
    'heal': 'Heal',
    'poison': 'Poison',
    'doNothing': 'Do nothing',
    'shoot': 'Shoot',
    'healQuestion': 'The wolves attacked {p}. Use your healing potion?',
    'noVictim': 'The wolves attacked nobody tonight.',
    'poisonPick': 'Poison someone (optional):',
    'potionsLeft': 'Potions: heal {h} · poison {p}',
    'seerKnown': 'What you have seen',
    'wolfPack': 'Your pack',
    'wolfPicks': 'Pack choices',
    'gameOver': 'Game over',
    'backToLobby': 'Back to lobby',
    'allRoles': 'Everyone\'s role',
    'winnerTag': 'Winner',
    'dead': 'Dead',
    'alive': 'Alive',
    'noMessages': 'No messages yet',
    'log.empty': 'The story begins when the game starts.',
    'lang.ar': 'العربية',
    'lang.en': 'English',

    'phase.lobby': 'Lobby',
    'phase.night': 'Night',
    'phase.witch': 'Night · the witch',
    'phase.day': 'Day · discussion',
    'phase.voting': 'Day · vote',
    'phase.hunter': 'The hunter\'s shot',
    'phase.ended': 'Game over',

    'team.village': 'Village',
    'team.wolves': 'Wolves',
    'team.neutral': 'Alone',

    'role.villager': 'Villager',
    'role.wolf': 'Wolf',
    'role.seer': 'Seer',
    'role.guardian': 'Guardian',
    'role.witch': 'Witch',
    'role.hunter': 'Hunter',
    'role.mayor': 'Mayor',
    'role.jester': 'Jester',
    'roleDesc.villager': 'No powers but your voice and your vote. Find the wolves.',
    'roleDesc.wolf': 'Each night, agree with your pack on someone to eat. By day, blend in.',
    'roleDesc.seer': 'Each night, look into one player and learn their true role.',
    'roleDesc.guardian': 'Each night, protect one player from the wolves. Not the same player twice in a row.',
    'roleDesc.witch': 'One potion to save the wolves\' victim, one potion to kill. Each works once.',
    'roleDesc.hunter': 'When you die, you take one player with you.',
    'roleDesc.mayor': 'Your vote counts twice.',
    'roleDesc.jester': 'You win alone if the village votes you out. Act suspicious!',

    'win.village': 'The village wins! Every wolf is gone.',
    'win.wolves': 'The wolves win! The village has fallen.',
    'win.jester': 'The jester wins! The village fell for the joke.',
    'win.none': 'The game is over.',

    'cause.wolves': '{p} was killed by the wolves.',
    'cause.poison': '{p} was poisoned.',
    'cause.vote': '{p} was voted out.',
    'cause.hunter': 'The hunter shot {p}.',

    'ev.gameStarted': 'The game begins with {n} players.',
    'ev.roleAssigned': 'You are the {role}.',
    'ev.nightFalls': 'Night {n} falls. Everyone, close your eyes…',
    'ev.wolvesChose': 'The pack has chosen {p}.',
    'ev.seerResult': 'Your vision: {p} is the {role}.',
    'ev.witchTurn': 'The wolves attacked {p}.',
    'ev.witchTurnNone': 'Nobody was attacked tonight.',
    'ev.dawn': 'The sun rises after night {n}.',
    'ev.wasRole': 'They were the {role}.',
    'ev.noDeaths': 'Nobody died last night.',
    'ev.discussion': 'Day {n}: talk it out. Who is a wolf?',
    'ev.votingStarted': 'Time to vote.',
    'ev.votedOut': 'The village voted out {p} ({n} votes).',
    'ev.tie': 'The vote is tied. Nobody leaves.',
    'ev.noVotes': 'Nobody was voted out.',
    'ev.hunterTurn': '{p} was the hunter and raises the bow…',
    'ev.hunterMissed': '{p} ran out of time and did not shoot.',
    'ev.paused': 'The host paused the game.',
    'ev.resumed': 'The game continues.',
    'ev.skipped': 'The host moved the game on.',

    'guide.narrator': 'You are the narrator. You see everything. Use pause and skip to run the game.',
    'guide.lobby': 'Wait here. The host chooses the roles and starts the game.',
    'guide.lobbyHost': 'Share the code, choose the roles, then start when everyone is in.',
    'guide.dead': 'You are dead. Watch, and talk only in the graveyard.',
    'guide.night.wolf': 'Choose a victim with your pack. Talk in the wolf den.',
    'guide.night.seer': 'Choose a player to see their role.',
    'guide.night.seerDone': 'You had your vision. Sleep now.',
    'guide.night.guardian': 'Choose a player to protect tonight.',
    'guide.night.witchWait': 'Wait. You will learn who the wolves attacked.',
    'guide.night.sleep': 'Close your eyes and wait for morning…',
    'guide.witch': 'Decide: heal the victim, poison someone, or do nothing.',
    'guide.day': 'Discuss with the village. Who is lying?',
    'guide.voting': 'Vote for who should leave the village.',
    'guide.voted': 'You voted. You can change it until time runs out.',
    'guide.hunter': 'You are dying. Shoot one player!',
    'guide.hunterWait': '{p} is choosing who to shoot…',

    'err.unknown': 'Something went wrong ({code}).',
    'err.notEnoughPlayers': 'At least 4 players are needed.',
    'err.tooManyPlayers': 'At most 16 players can play.',
    'err.needWolf': 'Add at least one wolf.',
    'err.tooManyRoles': 'More roles than players.',
    'err.tooManyWolves': 'Too many wolves for this many players.',
    'err.gameInProgress': 'A game is already running.',
    'err.roomLocked': 'The room is locked.',
    'err.roomFull': 'The room is full.',
    'err.wrongPassword': 'Wrong password.',
    'err.hostOnly': 'Only the host can do that.',
    'err.badTarget': 'You can\'t choose that player.',
    'err.notAllowed': 'You can\'t do that now.',
    'err.wrongPhase': 'Not now.',
    'err.alreadyActed': 'You already acted tonight.',
    'err.potionUsed': 'That potion is used up.',
    'err.nightSilence': 'The village sleeps. No talking at night.',
    'err.deadCannotTalk': 'The dead talk only in the graveyard.',
    'err.privateChatsOff': 'Private chats are off for this game.',
    'err.memberDead': 'Someone in this chat is dead.',
    'err.noAccess': 'You can\'t use this chat.',
    'err.kicked': 'The host removed you from the room.',
    'err.hostClosed': 'The host closed the room.',
    'err.unreachable': 'Couldn\'t reach the room. Check the Wi-Fi.',
    'err.versionMismatch': 'The host has a different app version.',
    'err.tooManyRooms': 'You have too many groups.',
    'err.emptyMessage': 'Write something first.',
    'err.badRequest': 'Invalid request.',
    'err.cannotPause': 'Can\'t pause now.',
    'err.notPaused': 'The game isn\'t paused.',
    'err.notInGame': 'No game is running.',
    'err.hostFailed': 'Couldn\'t open the room on this network.',
    'err.camera': 'Camera not available.',
  };

  static const _ar = <String, String>{
    'app': 'عُواء القمر',
    'tagline': 'ليلة ذئاب على شبكة الواي فاي',
    'host': 'استضافة لعبة',
    'join': 'الانضمام للعبة',
    'rejoin': 'العودة للعبة السابقة',
    'profile': 'الملف الشخصي',
    'editProfile': 'تعديل الملف',
    'name': 'اسمك',
    'nameRequired': 'اختر اسمًا أولًا',
    'avatar': 'الصورة الرمزية',
    'color': 'اللون',
    'photo': 'صورة',
    'pickPhoto': 'اختيار صورة',
    'removePhoto': 'إزالة الصورة',
    'save': 'حفظ',
    'cancel': 'إلغاء',
    'ok': 'حسنًا',
    'stats': 'إحصائياتك',
    'gamesPlayed': 'الألعاب',
    'wins': 'الانتصارات',
    'winRate': 'نسبة الفوز',
    'favoriteRole': 'الدور الأكثر',
    'language': 'اللغة',
    'sound': 'الأصوات',
    'vibration': 'الاهتزاز',
    'settings': 'الإعدادات',
    'roomName': 'اسم الغرفة',
    'roomNameHint': 'غرفة {name}',
    'passwordOptional': 'كلمة السر (اختياري)',
    'password': 'كلمة السر',
    'startHosting': 'فتح الغرفة',
    'hostKeepOpen': 'أبقِ التطبيق مفتوحًا أثناء الاستضافة، فاللعبة كلها تعمل من هاتفك.',
    'searching': 'جارٍ البحث عن غرف على هذه الشبكة…',
    'noRooms': 'لا توجد غرف بعد. تأكد أنك على نفس شبكة الواي فاي مع المضيف.',
    'scanQr': 'مسح رمز QR',
    'manual': 'إدخال العنوان',
    'address': 'العنوان (مثال 192.168.1.5:47474)',
    'connect': 'اتصال',
    'connecting': 'جارٍ الاتصال…',
    'reconnecting': 'انقطع الاتصال، جارٍ إعادة الاتصال…',
    'checking': 'جارٍ التحقق من الغرفة…',
    'roomNotFound': 'لا توجد غرفة على هذا العنوان.',
    'players': 'اللاعبون',
    'playersCount': '{n} لاعبين',
    'inGame': 'اللعبة جارية',
    'locked': 'مقفلة',
    'waitingHost': 'بانتظار المضيف لبدء اللعبة…',
    'startGame': 'ابدأ اللعبة',
    'roles': 'الأدوار',
    'autoRoles': 'تلقائي',
    'villagersFill': 'الباقي قرويون: {n}',
    'rolesSummary': '{special} أدوار خاصة لـ {players} لاعبين',
    'timers': 'المؤقتات (بالثواني)',
    'timer.night': 'الليل',
    'timer.witch': 'الساحرة',
    'timer.discussion': 'النقاش',
    'timer.voting': 'التصويت',
    'timer.hunter': 'الصياد',
    'opt.narrator': 'أنا الراوي (بدون دور)',
    'opt.reveal': 'كشف الدور عند الموت',
    'opt.deadSee': 'الموتى يرون كل الأدوار',
    'opt.private': 'السماح بالمحادثات الخاصة',
    'opt.publicVotes': 'إظهار من صوّت لمن',
    'lockRoom': 'قفل الغرفة',
    'kick': 'إخراج',
    'kickConfirm': 'إخراج {p} من الغرفة؟',
    'shareRoom': 'يمسح اللاعبون هذا الرمز أو يختارون الغرفة من القائمة',
    'youHost': 'المضيف',
    'narrator': 'الراوي',
    'you': 'أنت',
    'offline': 'غير متصل',
    'leave': 'خروج',
    'leaveConfirm': 'الخروج من اللعبة؟',
    'closeRoomConfirm': 'إغلاق الغرفة؟ سيُفصل جميع اللاعبين.',
    'yourRole': 'دورك',
    'tapReveal': 'اضغط لكشف دورك',
    'tapHide': 'اضغط للإخفاء',
    'teamLabel': 'الفريق: {team}',
    'pause': 'إيقاف مؤقت',
    'resume': 'استئناف',
    'skip': 'تخطي',
    'paused': 'متوقفة',
    'tab.game': 'اللعبة',
    'tab.chat': 'الدردشة',
    'tab.log': 'الحكاية',
    'chan.public': 'ساحة القرية',
    'chan.wolves': 'وكر الذئاب',
    'chan.dead': 'المقبرة',
    'newDm': 'رسالة خاصة',
    'newRoom': 'مجموعة جديدة',
    'groupName': 'اسم المجموعة',
    'members': 'الأعضاء',
    'create': 'إنشاء',
    'leaveGroup': 'مغادرة المجموعة',
    'typeMessage': 'اكتب رسالة…',
    'chooseTarget': 'اختر لاعبًا',
    'confirm': 'تأكيد',
    'vote': 'صوّت',
    'skipVote': 'امتناع',
    'youVotedSkip': 'اخترت الامتناع',
    'votes': 'أصوات',
    'heal': 'علاج',
    'poison': 'سُم',
    'doNothing': 'لا شيء',
    'shoot': 'أطلق',
    'healQuestion': 'هاجم الذئاب {p}. هل تستخدمين جرعة العلاج؟',
    'noVictim': 'لم يهاجم الذئاب أحدًا الليلة.',
    'poisonPick': 'اسقي أحدًا السم (اختياري):',
    'potionsLeft': 'الجرعات: علاج {h} · سم {p}',
    'seerKnown': 'ما رأيته',
    'wolfPack': 'قطيعك',
    'wolfPicks': 'اختيارات القطيع',
    'gameOver': 'انتهت اللعبة',
    'backToLobby': 'العودة للردهة',
    'allRoles': 'أدوار الجميع',
    'winnerTag': 'فائز',
    'dead': 'ميت',
    'alive': 'حي',
    'noMessages': 'لا توجد رسائل بعد',
    'log.empty': 'تبدأ الحكاية عند بدء اللعبة.',
    'lang.ar': 'العربية',
    'lang.en': 'English',

    'phase.lobby': 'الردهة',
    'phase.night': 'الليل',
    'phase.witch': 'الليل · الساحرة',
    'phase.day': 'النهار · النقاش',
    'phase.voting': 'النهار · التصويت',
    'phase.hunter': 'طلقة الصياد',
    'phase.ended': 'انتهت اللعبة',

    'team.village': 'القرية',
    'team.wolves': 'الذئاب',
    'team.neutral': 'منفرد',

    'role.villager': 'قروي',
    'role.wolf': 'ذئب',
    'role.seer': 'العرّافة',
    'role.guardian': 'الحارس',
    'role.witch': 'الساحرة',
    'role.hunter': 'الصياد',
    'role.mayor': 'العمدة',
    'role.jester': 'المهرّج',
    'roleDesc.villager': 'لا قوى لديك سوى صوتك وتصويتك. اكشف الذئاب.',
    'roleDesc.wolf': 'كل ليلة اتفق مع قطيعك على فريسة. وفي النهار تظاهر بالبراءة.',
    'roleDesc.seer': 'كل ليلة انظر في لاعب واحد واعرف دوره الحقيقي.',
    'roleDesc.guardian': 'كل ليلة احمِ لاعبًا من الذئاب، ولا يمكن حماية نفس اللاعب ليلتين متتاليتين.',
    'roleDesc.witch': 'جرعة لإنقاذ ضحية الذئاب وجرعة للقتل، كل منهما مرة واحدة.',
    'roleDesc.hunter': 'عندما تموت تأخذ معك لاعبًا واحدًا.',
    'roleDesc.mayor': 'صوتك يُحسب مرتين.',
    'roleDesc.jester': 'تفوز وحدك إذا طردتك القرية بالتصويت. تصرّف بشكل مريب!',

    'win.village': 'فازت القرية! لم يبقَ أي ذئب.',
    'win.wolves': 'فاز الذئاب! سقطت القرية.',
    'win.jester': 'فاز المهرّج! انطلت الخدعة على القرية.',
    'win.none': 'انتهت اللعبة.',

    'cause.wolves': 'افترس الذئاب {p}.',
    'cause.poison': 'مات {p} مسمومًا.',
    'cause.vote': 'طردت القرية {p}.',
    'cause.hunter': 'أطلق الصياد على {p}.',

    'ev.gameStarted': 'بدأت اللعبة بـ {n} لاعبين.',
    'ev.roleAssigned': 'دورك: {role}.',
    'ev.nightFalls': 'حلّت الليلة {n}. أغمضوا أعينكم…',
    'ev.wolvesChose': 'اختار القطيع {p}.',
    'ev.seerResult': 'رؤيتك: {p} هو {role}.',
    'ev.witchTurn': 'هاجم الذئاب {p}.',
    'ev.witchTurnNone': 'لم يُهاجَم أحد الليلة.',
    'ev.dawn': 'أشرقت الشمس بعد الليلة {n}.',
    'ev.wasRole': 'كان دوره: {role}.',
    'ev.noDeaths': 'لم يمت أحد الليلة الماضية.',
    'ev.discussion': 'اليوم {n}: تناقشوا. من هو الذئب؟',
    'ev.votingStarted': 'حان وقت التصويت.',
    'ev.votedOut': 'طردت القرية {p} ({n} أصوات).',
    'ev.tie': 'تعادل في الأصوات، لن يُطرد أحد.',
    'ev.noVotes': 'لم يُطرد أحد.',
    'ev.hunterTurn': 'كان {p} هو الصياد ويرفع قوسه…',
    'ev.hunterMissed': 'انتهى وقت {p} ولم يُطلق.',
    'ev.paused': 'أوقف المضيف اللعبة مؤقتًا.',
    'ev.resumed': 'تستمر اللعبة.',
    'ev.skipped': 'نقل المضيف اللعبة للمرحلة التالية.',

    'guide.narrator': 'أنت الراوي وترى كل شيء. استخدم الإيقاف والتخطي لإدارة اللعبة.',
    'guide.lobby': 'انتظر هنا. المضيف يختار الأدوار ويبدأ اللعبة.',
    'guide.lobbyHost': 'شارك الرمز، اختر الأدوار، ثم ابدأ عندما يدخل الجميع.',
    'guide.dead': 'أنت ميت. شاهد اللعبة، وتحدث فقط في المقبرة.',
    'guide.night.wolf': 'اختر فريسة مع قطيعك، وتحدثوا في وكر الذئاب.',
    'guide.night.seer': 'اختر لاعبًا لتكشف دوره.',
    'guide.night.seerDone': 'رأيت رؤيتك. نَم الآن.',
    'guide.night.guardian': 'اختر لاعبًا تحميه الليلة.',
    'guide.night.witchWait': 'انتظري، ستعرفين من هاجمه الذئاب.',
    'guide.night.sleep': 'أغمض عينيك وانتظر الصباح…',
    'guide.witch': 'قرري: عالجي الضحية، أو اسقي أحدًا السم، أو لا شيء.',
    'guide.day': 'تناقش مع القرية. من يكذب؟',
    'guide.voting': 'صوّت على من يجب أن يغادر القرية.',
    'guide.voted': 'صوّتّ. يمكنك التغيير حتى ينتهي الوقت.',
    'guide.hunter': 'أنت تحتضر. أطلق على لاعب واحد!',
    'guide.hunterWait': '{p} يختار على من يُطلق…',

    'err.unknown': 'حدث خطأ ({code}).',
    'err.notEnoughPlayers': 'تحتاج 4 لاعبين على الأقل.',
    'err.tooManyPlayers': 'الحد الأقصى 16 لاعبًا.',
    'err.needWolf': 'أضف ذئبًا واحدًا على الأقل.',
    'err.tooManyRoles': 'الأدوار أكثر من اللاعبين.',
    'err.tooManyWolves': 'عدد الذئاب كبير جدًا لهذا العدد من اللاعبين.',
    'err.gameInProgress': 'هناك لعبة جارية بالفعل.',
    'err.roomLocked': 'الغرفة مقفلة.',
    'err.roomFull': 'الغرفة ممتلئة.',
    'err.wrongPassword': 'كلمة السر خاطئة.',
    'err.hostOnly': 'هذا للمضيف فقط.',
    'err.badTarget': 'لا يمكنك اختيار هذا اللاعب.',
    'err.notAllowed': 'لا يمكنك فعل ذلك الآن.',
    'err.wrongPhase': 'ليس الآن.',
    'err.alreadyActed': 'لقد تصرفت بالفعل هذه الليلة.',
    'err.potionUsed': 'هذه الجرعة استُخدمت.',
    'err.nightSilence': 'القرية نائمة، لا كلام في الليل.',
    'err.deadCannotTalk': 'الموتى يتحدثون في المقبرة فقط.',
    'err.privateChatsOff': 'المحادثات الخاصة مغلقة في هذه اللعبة.',
    'err.memberDead': 'أحد أعضاء هذه المحادثة ميت.',
    'err.noAccess': 'لا يمكنك استخدام هذه المحادثة.',
    'err.kicked': 'أخرجك المضيف من الغرفة.',
    'err.hostClosed': 'أغلق المضيف الغرفة.',
    'err.unreachable': 'تعذر الوصول للغرفة. تحقق من الواي فاي.',
    'err.versionMismatch': 'إصدار التطبيق عند المضيف مختلف.',
    'err.tooManyRooms': 'لديك مجموعات كثيرة.',
    'err.emptyMessage': 'اكتب شيئًا أولًا.',
    'err.badRequest': 'طلب غير صالح.',
    'err.cannotPause': 'لا يمكن الإيقاف الآن.',
    'err.notPaused': 'اللعبة ليست متوقفة.',
    'err.notInGame': 'لا توجد لعبة جارية.',
    'err.hostFailed': 'تعذر فتح الغرفة على هذه الشبكة.',
    'err.camera': 'الكاميرا غير متاحة.',
  };
}

/// Emoji for each role, used on cards and in lists.
const roleEmoji = {
  Role.villager: '🧑‍🌾',
  Role.wolf: '🐺',
  Role.seer: '🔮',
  Role.guardian: '🛡️',
  Role.witch: '🧪',
  Role.hunter: '🏹',
  Role.mayor: '🎖️',
  Role.jester: '🃏',
};
