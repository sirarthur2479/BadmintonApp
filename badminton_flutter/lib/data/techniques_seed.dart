import '../models/technique.dart';

final List<Technique> kTechniquesSeed = [
  // ── FOOTWORK ─────────────────────────────────────────────────────────────
  Technique(
    id: 'fw_split_step',
    name: 'Split Step',
    category: 'Footwork',
    difficulty: 'beginner',
    relatedDrills: ['Shadow footwork', 'Reaction drill'],
    contentByLevel: {
      'beginner': TechniqueLevel(
        description:
            'The split step is a small jump done just as your opponent strikes the shuttle. It prepares your body to move in any direction quickly.',
        keyTips: [
          'Land with feet shoulder-width apart, knees slightly bent',
          'Time the jump to land exactly as opponent contacts shuttle',
          'Stay on the balls of your feet after landing',
          'Keep your weight balanced — not leaning to one side',
        ],
        commonMistakes: [
          'Jumping too early or too late',
          'Landing flat-footed and losing speed',
          'Splitting too wide, making it hard to push off',
        ],
      ),
      'intermediate': TechniqueLevel(
        description:
            'Refine your split step timing using your opponent\'s body position and racket angle as cues, allowing earlier preparation.',
        keyTips: [
          'Read opponent\'s shoulder rotation to predict shot direction',
          'Adjust split width based on court position',
          'Combine split step with first-step explosiveness',
          'Use a slight forward lean to bias movement toward the net',
        ],
        commonMistakes: [
          'Over-relying on the shuttle\'s flight path instead of reading the opponent',
          'Not recovering to base position before splitting again',
        ],
      ),
      'advanced': TechniqueLevel(
        description:
            'Elite players use a directional split — biasing body weight toward the anticipated shot before the opponent even makes contact.',
        keyTips: [
          'Develop deceptive split step to disguise your own positioning',
          'Vary jump height: smaller split for close shots, larger for wider coverage',
          'Integrate split step with overhead threat positioning',
        ],
        commonMistakes: [
          'Telegraphing direction during the split',
          'Skipping the split step when tired — exactly when it matters most',
        ],
      ),
    },
  ),

  Technique(
    id: 'fw_shadow',
    name: 'Shadow Footwork',
    category: 'Footwork',
    difficulty: 'beginner',
    relatedDrills: ['6-point shadow', 'Timed shadow circuit'],
    contentByLevel: {
      'beginner': TechniqueLevel(
        description:
            'Shadow footwork is a solo drill where you move to all six corners of the court without a shuttle, focusing purely on movement patterns.',
        keyTips: [
          'Always return to base (center) between each corner',
          'Use correct footwork for each corner (chasse, lunge, skip)',
          'Stay light on your feet — avoid stomping',
          'Keep racket up and ready throughout',
        ],
        commonMistakes: [
          'Rushing through corners without proper technique',
          'Forgetting to recover to base',
          'Looking down at feet instead of forward',
        ],
      ),
      'intermediate': TechniqueLevel(
        description:
            'Increase shadow speed and accuracy, mimicking real game scenarios with directional calls or patterns.',
        keyTips: [
          'Add a racket swing action at each corner to simulate real shots',
          'Use a partner to call out corners randomly',
          'Measure and improve your circuit time each week',
        ],
        commonMistakes: [
          'Sacrificing technique for speed',
          'Using the same footwork pattern for different court zones',
        ],
      ),
      'advanced': TechniqueLevel(
        description:
            'Advanced shadow work targets game-specific movement sequences and explosive acceleration/deceleration.',
        keyTips: [
          'Perform shadow under fatigue to build mental toughness',
          'Simulate multi-shot sequences (e.g., net → rear → net)',
          'Film yourself to compare with elite player footwork patterns',
        ],
        commonMistakes: [
          'Neglecting shadow when match play is available — shadow builds technical consistency',
        ],
      ),
    },
  ),

  Technique(
    id: 'fw_lunge',
    name: 'Lunge',
    category: 'Footwork',
    difficulty: 'intermediate',
    relatedDrills: ['Net lunge drill', 'Rear court lunge'],
    contentByLevel: {
      'beginner': TechniqueLevel(
        description:
            'The lunge is used to reach shuttles in the front corners. One foot extends far forward while keeping balance to return quickly.',
        keyTips: [
          'Lead with the racket-side foot toward the net',
          'Bend the front knee no further than your toes',
          'Keep your back straight, not hunched forward',
          'Push back off the lunging foot to recover',
        ],
        commonMistakes: [
          'Overreaching and losing balance',
          'Bending too low and not being able to recover',
          'Using the wrong foot to lead',
        ],
      ),
      'intermediate': TechniqueLevel(
        description:
            'Combine the lunge with net kill or net lift execution, maintaining deceptive body position.',
        keyTips: [
          'Keep the racket face open during lunge to disguise lift vs. net kill',
          'Use a scissor kick recovery for faster return to base',
          'Vary lunge depth based on shuttle height',
        ],
        commonMistakes: [
          'Always using maximum lunge — adapt depth to shuttle position',
          'Not watching opponent while in the lunge',
        ],
      ),
      'advanced': TechniqueLevel(
        description:
            'Master the cross-step lunge and reverse lunge for reaching extreme angles while maintaining tactical deception.',
        keyTips: [
          'Cross-step lunge allows reaching wider angles without losing balance',
          'Use one-finger grip adjustment during the lunge for better angle control',
          'Practice lunge recovery into split step seamlessly',
        ],
        commonMistakes: [
          'Planting the foot before the shuttle arrives, telegraphing position',
        ],
      ),
    },
  ),

  Technique(
    id: 'fw_recovery',
    name: 'Recovery Step',
    category: 'Footwork',
    difficulty: 'intermediate',
    relatedDrills: ['Shadow recovery circuit', 'Multi-shuttle recovery'],
    contentByLevel: {
      'beginner': TechniqueLevel(
        description:
            'After every shot, return to base position (center of the court) using efficient recovery steps.',
        keyTips: [
          'Base position: approximately 1 step behind the service line, centered',
          'Use chasse (side-step) to recover from net shots',
          'Use cross-step to recover from rear-court shots',
          'Recover before the opponent plays their next shot',
        ],
        commonMistakes: [
          'Standing still after playing a shot',
          'Walking instead of running back',
          'Recovering too far — position depends on your previous shot',
        ],
      ),
      'intermediate': TechniqueLevel(
        description:
            'Adjust recovery position dynamically based on the quality of your last shot and opponent\'s likely reply.',
        keyTips: [
          'After an attacking shot, recover forward to intercept net replies',
          'After a weak lift, recover deeper to handle smashes',
          'Use split step timed to your recovery end-point',
        ],
        commonMistakes: [
          'Always recovering to the same base regardless of tactical situation',
        ],
      ),
      'advanced': TechniqueLevel(
        description:
            'Elite recovery involves anticipation — beginning recovery movement before the shot is even completed.',
        keyTips: [
          'Use body rotation momentum to initiate recovery while the shuttle is still in the air',
          'Shadow opponent movement to maintain court dominance',
          'Combine recovery with tactical threatening positions',
        ],
        commonMistakes: [
          'Recovering too predictably, allowing opponent to exploit open court',
        ],
      ),
    },
  ),

  // ── STROKES ──────────────────────────────────────────────────────────────
  Technique(
    id: 'st_smash',
    name: 'Smash',
    category: 'Stroke',
    difficulty: 'intermediate',
    relatedDrills: ['Smash and recover', 'Multi-shuttle smash feed'],
    contentByLevel: {
      'beginner': TechniqueLevel(
        description:
            'The smash is the primary attacking shot in badminton — a fast, steeply angled downward stroke hit from above the head.',
        keyTips: [
          'Get behind the shuttle before hitting — position is key',
          'Rotate shoulder and trunk for power, not just arm strength',
          'Strike shuttle at the highest point you can comfortably reach',
          'Snap the wrist at contact for pace and steep angle',
          'Follow through downward and toward the target',
        ],
        commonMistakes: [
          'Hitting too flat — smash should travel steeply downward',
          'Using only arm strength without body rotation',
          'Letting the shuttle drop too low before hitting',
          'Poor grip — too tight throughout the swing instead of loose then snap',
        ],
      ),
      'intermediate': TechniqueLevel(
        description:
            'Develop directional smashing: straight, cross-court, and body smash. Each requires small adjustments to contact point and swing path.',
        keyTips: [
          'Straight smash: contact shuttle slightly in front, swing through middle of body',
          'Cross-court smash: contact slightly later with wrist rotation',
          'Body smash: aim at opponent\'s hip to force awkward return',
          'Mix power smash with half-smash to vary pace',
        ],
        commonMistakes: [
          'Telegraphing direction through pre-swing body positioning',
          'Neglecting body smash — it\'s often harder to return than a corner smash',
        ],
      ),
      'advanced': TechniqueLevel(
        description:
            'Advanced smashing combines deception, jump smash, and tactical placement to create outright winners or force specific weak returns.',
        keyTips: [
          'Jump smash: jump to hit at a steeper angle and add body weight',
          'Use sliced smash to create unpredictable trajectory',
          'Follow net with your body after smashing to intercept the block',
          'Time smash in sequences — often the 3rd shot in a rally wins the point',
        ],
        commonMistakes: [
          'Smashing every clear — vary with drops to keep opponent guessing',
          'Not following up the smash with net positioning',
        ],
      ),
    },
  ),

  Technique(
    id: 'st_drop',
    name: 'Drop Shot',
    category: 'Stroke',
    difficulty: 'beginner',
    relatedDrills: ['Drop and net', 'Cross-court drop drill'],
    contentByLevel: {
      'beginner': TechniqueLevel(
        description:
            'The drop shot is a soft shot played from the rear court that falls steeply near the net on the opponent\'s side.',
        keyTips: [
          'Use the same swing preparation as a smash to deceive opponent',
          'Slow down racket speed at contact — don\'t follow through fully',
          'Aim to land the shuttle just over the net, near the side tramline',
          'Straight drop: safer option, harder for opponent to counter-attack',
        ],
        commonMistakes: [
          'Obvious deceleration of the racket before impact — telegraphs the shot',
          'Hitting the drop too high, giving opponent time to reach it',
          'Not returning to base after playing the drop',
        ],
      ),
      'intermediate': TechniqueLevel(
        description:
            'Master the fast drop and slow drop. Use fast drop to press opponent; slow drop (hairpin) to force a net lift.',
        keyTips: [
          'Fast drop: harder hit, faster trajectory, lands midcourt',
          'Slow drop (hairpin): feather touch, tumbles over net',
          'Disguise with a fake smash backswing',
          'Play cross-court drop when opponent is central to create wider angle',
        ],
        commonMistakes: [
          'Always playing the same type of drop — mix fast and slow',
          'Cross-court drop too central — must land near the sideline to be effective',
        ],
      ),
      'advanced': TechniqueLevel(
        description:
            'Advanced drops use minimal swing differences from smash to create unreadable deception.',
        keyTips: [
          'Sliced drop: racket brushes under the shuttle creating a spinning trajectory',
          'Reverse slice: spin goes opposite direction for extra deception',
          'Use drop to pull opponent forward, then follow with smash to open court',
        ],
        commonMistakes: [
          'Over-using drops after establishing a smash threat — mix strategically',
        ],
      ),
    },
  ),

  Technique(
    id: 'st_clear',
    name: 'Clear',
    category: 'Stroke',
    difficulty: 'beginner',
    relatedDrills: ['Clear and recover', 'Overhead clear rally'],
    contentByLevel: {
      'beginner': TechniqueLevel(
        description:
            'The clear sends the shuttle high and deep to the opponent\'s rear court, giving you time to recover position.',
        keyTips: [
          'Hit shuttle at full arm extension above your head',
          'Push shuttle toward the back boundary line',
          'Defensive clear: high and deep to buy time',
          'Keep watching the shuttle all the way to contact',
        ],
        commonMistakes: [
          'Clear falling short — opponent can attack',
          'Hitting with a bent arm, reducing power and height',
          'Not recovering to base after playing the clear',
        ],
      ),
      'intermediate': TechniqueLevel(
        description:
            'Learn attacking clear (flatter, faster) vs. defensive clear (higher, deeper). Use attacking clear to push opponent back.',
        keyTips: [
          'Attacking clear: flatter trajectory, lands near rear tramline',
          'Defensive clear: maximize height to give yourself recovery time',
          'Use same swing as smash and drop to maintain deception',
          'Target rear corners, not the center',
        ],
        commonMistakes: [
          'Playing defensive clear when attacking clear is the better tactical choice',
          'Clearing to the center — always aim for corners',
        ],
      ),
      'advanced': TechniqueLevel(
        description:
            'The advanced clear is a tactical weapon used to reset rallies, exploit opponent out of position, or set up your next attack.',
        keyTips: [
          'Use a clear when opponent is near the net to force them back',
          'Vary between left and right rear corners each clear to move opponent',
          'A well-placed clear can be as threatening as a smash',
        ],
        commonMistakes: [
          'Clearing predictably — opponent reads your patterns and anticipates',
        ],
      ),
    },
  ),

  Technique(
    id: 'st_net_kill',
    name: 'Net Kill',
    category: 'Stroke',
    difficulty: 'intermediate',
    relatedDrills: ['Net kill reaction drill', 'Tight net feed'],
    contentByLevel: {
      'beginner': TechniqueLevel(
        description:
            'The net kill is an aggressive shot played at the net when the shuttle is above tape height — punch it steeply downward.',
        keyTips: [
          'Only play net kill when shuttle is above the net tape',
          'Use a short, punchy wrist action — not a big swing',
          'Aim straight down toward the opponent\'s feet or body',
          'Stay balanced on the lunge — don\'t over-reach',
        ],
        commonMistakes: [
          'Attempting net kill when shuttle is below tape — lifts it up instead',
          'Hitting into the net from a large swing',
          'Not being close enough to the net before striking',
        ],
      ),
      'intermediate': TechniqueLevel(
        description:
            'Develop net kill variations: straight kill, cross-court kill, and push. Choose based on opponent\'s position.',
        keyTips: [
          'If opponent is central: straight or cross-court kill to the widest gap',
          'Feint a net kill then lift if opponent lunges early',
          'Use the push (softer kill) when opponent is already covering corners',
        ],
        commonMistakes: [
          'Always using maximum force — a soft net kill away from opponent is equally effective',
        ],
      ),
      'advanced': TechniqueLevel(
        description:
            'Elite net kills are executed from the earliest possible interception point, denying opponent reaction time.',
        keyTips: [
          'Intercept at the highest point above the tape for steepest angle',
          'Disguise kill with a net-lift grip position until the last moment',
          'Use net kill threat to force opponent into lifting higher — then punish',
        ],
        commonMistakes: [
          'Hesitating and allowing the shuttle to drop — attack when it\'s above tape',
        ],
      ),
    },
  ),

  Technique(
    id: 'st_net_lift',
    name: 'Net Lift',
    category: 'Stroke',
    difficulty: 'beginner',
    relatedDrills: ['Tight net rally', 'Lift and smash sequence'],
    contentByLevel: {
      'beginner': TechniqueLevel(
        description:
            'The net lift sends a tight net shuttle high to the rear court, used defensively when you cannot attack the shuttle.',
        keyTips: [
          'Use an open racket face to scoop the shuttle upward',
          'Aim for the rear corners — never lift to the center',
          'Get as low as possible to maintain control',
          'Recover immediately after lifting — you are now defending',
        ],
        commonMistakes: [
          'Lifting too short — lands in midcourt and opponent smashes from close range',
          'Lifting to the center — opponent has full smash options',
          'Slow recovery after the lift',
        ],
      ),
      'intermediate': TechniqueLevel(
        description:
            'Use the lift tactically: a cross-court lift can move opponent and create better court coverage.',
        keyTips: [
          'Straight lift: safer, less angle for opponent',
          'Cross-court lift: moves opponent across the court but riskier',
          'Change lift height to disrupt opponent\'s timing',
        ],
        commonMistakes: [
          'Predictable lift direction — vary to make opponent work',
        ],
      ),
      'advanced': TechniqueLevel(
        description:
            'Advanced players use the net lift with deception, disguising it as a net kill to hold the opponent at the rear.',
        keyTips: [
          'Combine net lift threat with net kill to keep opponent guessing',
          'Use flick lift (quick wrist action) to gain extra distance while off-balance',
        ],
        commonMistakes: [
          'Lifting instead of killing when given a clear opportunity above tape height',
        ],
      ),
    },
  ),

  // ── SERVES ───────────────────────────────────────────────────────────────
  Technique(
    id: 'sv_low',
    name: 'Low Serve',
    category: 'Serve',
    difficulty: 'beginner',
    relatedDrills: ['Serve accuracy drill', 'Serve and return rally'],
    contentByLevel: {
      'beginner': TechniqueLevel(
        description:
            'The low serve travels just over the net tape and falls into the front service box. It is the most common serve in doubles and advanced singles.',
        keyTips: [
          'Hold shuttle by feather or cork at waist height',
          'Use a short, controlled push — no backswing',
          'Aim for the shuttle to skim just above the net tape',
          'Serve to the T (center service line) in doubles',
        ],
        commonMistakes: [
          'Serving too high — receiver can attack it',
          'Serving too short — hits the net',
          'Standing too close to the short service line',
          'Telegraphing serve direction with body position',
        ],
      ),
      'intermediate': TechniqueLevel(
        description:
            'Develop serve placement: T, body, and wide serves. Each targets a different weakness in the receiver.',
        keyTips: [
          'T serve: forces receiver to move across and opens court',
          'Body serve: receiver must adjust to play backhand or forehand',
          'Wide serve (singles): pushes receiver to the sideline',
          'Vary placement randomly to prevent receiver anticipation',
        ],
        commonMistakes: [
          'Using only the T serve — experienced receivers anticipate easily',
        ],
      ),
      'advanced': TechniqueLevel(
        description:
            'Advanced low serve uses minimal racket movement and variable cork contact points for maximum deception.',
        keyTips: [
          'Develop a serve that looks identical to a flick serve until impact',
          'Use serve-and-follow by stepping into position immediately after serving',
          'Target the receiver\'s body in doubles to make backhand pushes awkward',
        ],
        commonMistakes: [
          'Serving predictably based on score or pressure — vary even on crucial points',
        ],
      ),
    },
  ),

  Technique(
    id: 'sv_flick',
    name: 'Flick Serve',
    category: 'Serve',
    difficulty: 'intermediate',
    relatedDrills: ['Serve mix drill', 'Flick serve accuracy'],
    contentByLevel: {
      'beginner': TechniqueLevel(
        description:
            'The flick serve uses a quick wrist snap to push the shuttle high over an attacking receiver, landing near the rear service line.',
        keyTips: [
          'Same preparation as the low serve — deception is the key',
          'Quick wrist snap at contact sends shuttle high',
          'Aim for the rear corners to maximize difficulty for receiver',
          'Do not telegraph with a bigger backswing',
        ],
        commonMistakes: [
          'Different preparation from the low serve — receiver reads it early',
          'Flick too short — lands midcourt and gives opponent easy smash',
          'Using the flick too often — loses deception value',
        ],
      ),
      'intermediate': TechniqueLevel(
        description:
            'Develop precise flick serve targeting and use it situationally to punish receivers who are rushing the low serve.',
        keyTips: [
          'Use flick when receiver is leaning forward to attack the low serve',
          'Target backhand rear corner — most players are weaker there',
          'Combine with body language that suggests the low serve',
        ],
        commonMistakes: [
          'Overusing flick — must be unpredictable, not a pattern',
        ],
      ),
      'advanced': TechniqueLevel(
        description:
            'The advanced flick serve includes a drive serve variation and uses micro-timing differences undetectable to opponents.',
        keyTips: [
          'Drive serve: fast and flat, aimed at opponent\'s body for doubles',
          'Vary flick height to disrupt receiver\'s jump timing',
          'Use slightly different contact point (toward feather vs cork) for spin variations',
        ],
        commonMistakes: [
          'Flicking when the receiver is already reading the serve — switch to low serve to surprise',
        ],
      ),
    },
  ),

  Technique(
    id: 'sv_drive',
    name: 'Drive Serve',
    category: 'Serve',
    difficulty: 'advanced',
    relatedDrills: ['Drive serve practice', 'Serve return reaction drill'],
    contentByLevel: {
      'beginner': TechniqueLevel(
        description:
            'The drive serve travels fast and flat directly at the receiver\'s body, used primarily in doubles to rush the return.',
        keyTips: [
          'Aim at the receiver\'s hip or shoulder for maximum awkwardness',
          'Use in doubles when receiver is positioned to intercept net serves',
          'Keep the serve legal — contact below waist, racket head below hand',
        ],
        commonMistakes: [
          'Using drive serve too predictably',
          'Serving too wide — goes out of bounds or is easy to return',
          'Illegal serve action (racket above waist at contact)',
        ],
      ),
      'intermediate': TechniqueLevel(
        description:
            'Use drive serve situationally as a surprise within a low/flick serve mix.',
        keyTips: [
          'Best used when receiver is standing wide expecting low serve to T',
          'Aim slightly wider than the body to make backhand return difficult',
          'Follow drive serve with net coverage immediately',
        ],
        commonMistakes: [
          'Drive serving from wrong stance — should still use low serve preparation',
        ],
      ),
      'advanced': TechniqueLevel(
        description:
            'The drive serve is a high-risk high-reward weapon. At advanced level, disguise is absolute and placement is surgical.',
        keyTips: [
          'Combine drive serve threat with low serve in crucial rallies',
          'Target different body zones: hip, shoulder, and forehand elbow',
          'Read receiver body weight shift to time the drive serve perfectly',
        ],
        commonMistakes: [
          'Using drive serve when serving from the left court — angle is exposed',
        ],
      ),
    },
  ),

  // ── TACTICS ──────────────────────────────────────────────────────────────
  Technique(
    id: 'ta_cross_court',
    name: 'Cross-Court Play',
    category: 'Tactics',
    difficulty: 'intermediate',
    relatedDrills: ['Cross-court rally', 'Diagonal movement drill'],
    contentByLevel: {
      'beginner': TechniqueLevel(
        description:
            'Cross-court shots travel diagonally across the net, covering more distance than straight shots and creating wider angles.',
        keyTips: [
          'Cross-court smash: opponent has further to move and cover',
          'Cross-court net shot: creates the widest possible angle',
          'Use cross-court when opponent is recovering to one side',
          'Always be ready for a straight reply after playing cross-court',
        ],
        commonMistakes: [
          'Playing cross-court when opponent is already covering that side',
          'Cross-court shots that don\'t have enough angle — end up in center',
          'Not recovering after playing cross-court — leaves straight side open',
        ],
      ),
      'intermediate': TechniqueLevel(
        description:
            'Use cross-court shots tactically within rallies to create openings rather than as a default pattern.',
        keyTips: [
          'Set up a cross-court shot by playing several straight shots first',
          'Cross-court drop followed by straight net shot is a classic combination',
          'In doubles: cross-court forces a change of assignments between partners',
        ],
        commonMistakes: [
          'Cross-court when opponent can intercept at the net — play straight instead',
        ],
      ),
      'advanced': TechniqueLevel(
        description:
            'Advanced cross-court play involves reading opponent\'s body position and using cross-court threats without always executing them.',
        keyTips: [
          'Hold cross-court threat to pull opponent and then play straight',
          'Mix cross-court angles: sharp, medium, and wide within the same shot type',
          'In doubles: use cross-court to attack the seam between partners',
        ],
        commonMistakes: [
          'Playing the same cross-court pattern — opponents learn to anticipate and poach',
        ],
      ),
    },
  ),

  Technique(
    id: 'ta_deception',
    name: 'Deception',
    category: 'Tactics',
    difficulty: 'advanced',
    relatedDrills: ['Hold and release drill', 'Feint practice'],
    contentByLevel: {
      'beginner': TechniqueLevel(
        description:
            'Deception makes your opponent move in the wrong direction before you play your actual shot.',
        keyTips: [
          'Same swing preparation for different shot outcomes',
          'Slow the swing down late to change from smash to drop',
          'Use eye and shoulder fakes to suggest a direction',
          'Start with drop-shot disguised as clear before learning advanced deception',
        ],
        commonMistakes: [
          'Large backswing changes that reveal shot type early',
          'Inconsistent technique — deception requires a solid base stroke first',
          'Using deception before mastering the basic shots',
        ],
      ),
      'intermediate': TechniqueLevel(
        description:
            'Develop specific deceptive shots: hold-and-drop, reverse slice, and reverse net cross.',
        keyTips: [
          'Hold-and-drop: extend arm as if clearing, then drop shuttle softly at net',
          'Reverse slice net shot: appears to go straight, slides cross-court',
          'Body language mismatch: look one way, play another',
        ],
        commonMistakes: [
          'Overusing the same deceptive technique until it becomes predictable',
          'Attempting deception under fatigue and losing control of the shot',
        ],
      ),
      'advanced': TechniqueLevel(
        description:
            'Elite deception is seamlessly integrated into every shot — opponents cannot read intent until shuttle contact.',
        keyTips: [
          'Develop dual-option technique: same motion can produce two different shots based on last-moment wrist',
          'Use deception on critical points specifically to exploit high-pressure opponent tendencies',
          'Combine physical deception with tactical deception (pattern breaking)',
        ],
        commonMistakes: [
          'Using deception when a clean winner is available — simpler is often better',
        ],
      ),
    },
  ),

  Technique(
    id: 'ta_court_coverage',
    name: 'Court Coverage',
    category: 'Tactics',
    difficulty: 'intermediate',
    relatedDrills: ['Court coverage shadow', 'Positional awareness drill'],
    contentByLevel: {
      'beginner': TechniqueLevel(
        description:
            'Court coverage is about positioning yourself so the smallest movement reaches any shot your opponent can play.',
        keyTips: [
          'Base position: center of your realistic reply options, not the geometric center',
          'After each shot, return toward base before opponent contacts shuttle',
          'Anticipate: watch opponent\'s body, not the shuttle',
          'Cover the most dangerous reply first',
        ],
        commonMistakes: [
          'Standing still after hitting a shot',
          'Returning to the same spot regardless of previous shot',
          'Watching the shuttle instead of opponent\'s movement',
        ],
      ),
      'intermediate': TechniqueLevel(
        description:
            'Adjust base position dynamically based on rally situation: defend differently after a weak lift vs. after a good smash.',
        keyTips: [
          'After a weak shot: defend deeper, wider base',
          'After a strong attack: move forward, narrow base',
          'In doubles: coordinate positioning with partner to cover the full court',
          'Use shot selection to improve your next coverage position',
        ],
        commonMistakes: [
          'Static positional thinking — good coverage is always dynamic',
        ],
      ),
      'advanced': TechniqueLevel(
        description:
            'Advanced court coverage involves proactive positioning — moving to where the shuttle will be before opponent plays.',
        keyTips: [
          'Read opponent body angle and racket face to position before the shot',
          'Threaten space to force opponent into your preferred zone',
          'Use positional pressure as a tactical weapon without even hitting the shuttle',
        ],
        commonMistakes: [
          'Anticipating too early and being caught wrong-footed if opponent changes direction',
        ],
      ),
    },
  ),
];
