#include <uwsgi.h>

int zig_request_handler(struct wsgi_request *);
int zig_add_env(void *, char *, char *);
int zig_load_fn(char *);

extern struct uwsgi_server uwsgi;
struct uwsgi_plugin zsgi_plugin;

struct uwsgi_zig {
	// function to call in the current address space
	char *fn;
} uzig;

static struct uwsgi_option zig_options[] = {
	{"zig-fn", required_argument, 0, "zig function to call at every request", uwsgi_opt_set_str, &uzig.fn, 0},
	UWSGI_END_OF_OPTIONS
};

// map the function entry point
static void zig_apps() {
	uwsgi_log("[zsgi] attempting to load zsgi apps\n");
	if (!uzig.fn) return;

	if (zig_load_fn(uzig.fn)) {
		uwsgi_log("[zsgi] unable to find function \"%s\"\n", uzig.fn);
		exit(1);
	}

	uwsgi_log("[zsgi] here.\n");
	time_t now = uwsgi_now();
	int id = uwsgi_apps_cnt;

	uwsgi_log("[zsgi] found %d apps.\n", id);
	struct uwsgi_app *ua = uwsgi_add_app(id, zsgi_plugin.modifier1, "", 0, NULL, NULL);
        if (!ua) {
                uwsgi_log("[zsgi] unable to mount app\n");
                exit(1);
        }

        ua->responder0 = uzig.fn;
        ua->responder1 = uzig.fn;
        ua->started_at = now;
        ua->startup_time = uwsgi_now() - now;
        uwsgi_log("[zsgi] app/mountpoint %d loaded in %d seconds\n", id, (int) ua->startup_time);

	uwsgi_emulate_cow_for_apps(id);
}

// populate environment HashMap
int uwsgi_zig_build_env(struct wsgi_request *wsgi_req, void *hm) {
	int i;
	for(i=0;i<wsgi_req->var_cnt;i++) {
		char *key = (char *)wsgi_req->hvec[i].iov_base;
		char *val = (char *)wsgi_req->hvec[i+1].iov_base;
		if (zig_add_env(hm, key, val)) return -1;
                i++;
        }

	return 0;
}

static int zig_request(struct wsgi_request *wsgi_req) {

#if UWSGI_PLUGIN_API >= 2
        if (!wsgi_req->len) {
#else
        if (!wsgi_req->uh->pktsize) {
#endif
                uwsgi_log("Empty request. skip.\n");
                return -1;
        }

        if (uwsgi_parse_vars(wsgi_req)) {
                return -1;
        }

	wsgi_req->app_id = uwsgi_get_app_id(wsgi_req, wsgi_req->appid, wsgi_req->appid_len, zsgi_plugin.modifier1);
	if (wsgi_req->app_id == -1 && !uwsgi.no_default_app && uwsgi.default_app > -1) {
                if (uwsgi_apps[uwsgi.default_app].modifier1 == zsgi_plugin.modifier1) {
                        wsgi_req->app_id = uwsgi.default_app;
                }
        }

        if (wsgi_req->app_id == -1) {
                uwsgi_404(wsgi_req);
                return UWSGI_OK;
        }

	return zig_request_handler(wsgi_req);
}

struct uwsgi_plugin zsgi_plugin = {
	.name = "zsgi",
	.modifier1 = 0,
	.options = zig_options,
	.init_apps = zig_apps,
	.request = zig_request,
	.after_request = log_request,
};