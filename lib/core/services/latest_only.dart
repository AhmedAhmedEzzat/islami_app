import 'dart:async';

/// Runs jobs one at a time, and when several are waiting only the newest.
///
/// For work that replaces what the last run did, such as rebuilding the
/// notification schedule: two runs at once would undo each other's work in
/// whatever order the platform happened to answer, and a run that has been
/// overtaken is wasted effort, so it is told to stop.
class LatestOnly {
  int _latest = 0;
  Future<void> _tail = Future<void>.value();

  /// Runs [job] once every job asked for before it has finished or given up.
  ///
  /// [job] is handed `superseded`, which turns true as soon as a newer job is
  /// asked for; it should check it between steps and return early. A job that
  /// is overtaken before its turn does not run at all.
  Future<void> run(Future<void> Function(bool Function() superseded) job) {
    final id = ++_latest;
    bool superseded() => id != _latest;
    final done = _tail.then((_) async {
      if (superseded()) return;
      await job(superseded);
    });
    // The next job waits for this one whether or not it failed.
    _tail = done.then<void>((_) {}, onError: (_) {});
    return done;
  }
}
