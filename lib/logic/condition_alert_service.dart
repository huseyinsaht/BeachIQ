import 'swim_suitability.dart';

/// Decides whether a "conditions turned favorable" alert should fire,
/// given the previous and the newly-computed [SwimVerdict] for a picked
/// location.
///
/// This is the first slice of the alerting feature (issue #87): a pure,
/// platform-agnostic trigger decision. It does not send, schedule or
/// permission-check any actual notification — that is left to a follow-up
/// issue that wires this decision into a real delivery mechanism (see the
/// class doc below for what that follow-up needs).
///
/// Usage: the caller (e.g. a background poller once one exists) keeps track
/// of the last [SwimVerdict] it saw for a location, calls
/// [scoreSwimSuitability] again, and asks [shouldAlert] whether the change
/// between the two verdicts warrants notifying the user. The caller is also
/// responsible for persisting [alertsEnabled] (e.g. in shared preferences)
/// and constructing this service with the current value.
///
/// Follow-up work (out of scope here): actually showing a notification
/// needs the `flutter_local_notifications` package (or platform channel
/// equivalent), Android POST_NOTIFICATIONS / iOS UNUserNotificationCenter
/// permission requests and handling of denial, plus a background scheduling
/// mechanism (e.g. periodic work via `workmanager`/`android_alarm_manager`
/// or a foreground polling timer) to actually produce the "new" verdict to
/// feed into [shouldAlert] while the app isn't open.
class ConditionAlertService {
  /// Creates a service with alerts either enabled or disabled.
  ///
  /// [alertsEnabled] is the on/off toggle the caller persists (e.g. a user
  /// setting). When `false`, [shouldAlert] always returns `false`
  /// regardless of the verdict transition.
  const ConditionAlertService({this.alertsEnabled = true});

  /// Whether the user has alerts turned on at all. When `false`,
  /// [shouldAlert] never fires.
  final bool alertsEnabled;

  /// Returns `true` if the transition from [previous] to [current] is a
  /// meaningful improvement that should notify the user that conditions
  /// have turned favorable.
  ///
  /// An alert only fires when:
  /// - alerts are enabled ([alertsEnabled] is `true`), and
  /// - [current] is [SwimSuitabilityLevel.good] (favorable), and
  /// - [previous] was NOT [SwimSuitabilityLevel.good] (i.e. it was
  ///   [SwimSuitabilityLevel.caution], [SwimSuitabilityLevel.poor] or
  ///   [SwimSuitabilityLevel.unknown]).
  ///
  /// This means it never fires on every poll (good → good is a no-op), and
  /// it never fires on a downgrade (e.g. good → poor), only on the
  /// meaningful "conditions just became swimmable" transition.
  bool shouldAlert({required SwimVerdict previous, required SwimVerdict current}) {
    if (!alertsEnabled) return false;

    final becameFavorable = current.level == SwimSuitabilityLevel.good;
    final wasNotAlreadyFavorable = previous.level != SwimSuitabilityLevel.good;

    return becameFavorable && wasNotAlreadyFavorable;
  }
}
