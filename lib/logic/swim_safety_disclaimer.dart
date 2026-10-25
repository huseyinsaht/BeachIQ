/// Copy for the swim-safety disclaimer (issue #271). The Home screen's
/// [SwimSuggestionPill] (`presentation/widgets/swim_suggestion_pill.dart`)
/// shows a short verdict message ("Calm seas — good time for a swim.")
/// that, read alone, can sound like a safety guarantee. This disclaimer
/// states the verdict's real limits -- mirroring the existing
/// `depthApproximationCaveat` pattern in `shallow_entry_verdict.dart`,
/// which never uses the word "safe" either.
library;

/// Title of the disclaimer sheet opened from the verdict pill's info icon.
const String swimSafetyDisclaimerTitle = 'A guide, not a guarantee';

/// Body of the disclaimer sheet. Never claims the app's suggestion is a
/// safety guarantee, and defers to local flags/lifeguards. Wording in
/// English only -- localization is a separate, later concern per the
/// issue.
const String swimSafetyDisclaimer =
    'This suggestion is a model estimate based on forecast data, not a '
    'safety guarantee. Conditions can change quickly and the model can be '
    'wrong. Always follow local flags and lifeguard instructions -- they '
    'take precedence over this app.';

/// General rip-current advice shown under [swimSafetyDisclaimer] (issue
/// #275). Standard public-safety guidance, not a prediction: BeachIQ has no
/// rip-current data (they form within ~50-100 m of shore, below the
/// resolution of any open dataset it uses) and never shows a rip score.
const String ripCurrentSafetyTip =
    'Rip currents can form on any beach, most often in rough water. Swim '
    'near a lifeguard. If you are pulled out, stay calm, do not fight the '
    'current, swim parallel to the shore until free, then head back in.';
