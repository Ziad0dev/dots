"""Lets other programs open a search in the running Nicotine+.

`slsk-search QUERY` (home/soulseek.nix) drops a file holding the query into
$XDG_RUNTIME_DIR/slsk-search; this plugin picks it up within a second and
opens it as a global search tab. Queries wait while the client is logged out,
so one queued before Nicotine+ has started runs as soon as it connects.
"""
import os
import time

from pynicotine.events import events
from pynicotine.pluginsystem import BasePlugin
from pynicotine.slskmessages import UserStatus


class Plugin(BasePlugin):

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        runtime = os.environ.get("XDG_RUNTIME_DIR")
        self.queue = os.path.join(runtime, "slsk-search") if runtime else None
        self.timer = None

    def loaded_notification(self):
        if self.queue:
            self.timer = events.schedule(delay=1, callback=self.poll, repeat=True)

    def disable(self):
        if self.timer is not None:
            events.cancel_scheduled(self.timer)
            self.timer = None

    def poll(self):
        if self.core.users.login_status == UserStatus.OFFLINE:
            return
        try:
            names = sorted(n for n in os.listdir(self.queue) if not n.startswith("."))
        except OSError:
            return
        for name in names:
            path = os.path.join(self.queue, name)
            try:
                stale = time.time() - os.path.getmtime(path) > 600
                with open(path, encoding="utf-8") as f:
                    query = f.read().strip()
                os.unlink(path)
            except OSError:
                continue
            # a query nobody was around to run isn't wanted an hour later
            if query and not stale:
                self.log("Searching for: %s", query)
                self.core.search.do_search(query, mode="global")
