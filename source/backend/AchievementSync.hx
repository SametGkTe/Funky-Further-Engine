package backend;

import haxe.Json;
import flixel.FlxG;
import objects.AlertMgr.AlertMsg;

class AchievementSync {
    public static inline var GAME_VERSION:String = '1.0.4';

    #if android
    static inline var PLATFORM:String = 'android';
    #elseif windows
    static inline var PLATFORM:String = 'windows';
    #elseif linux
    static inline var PLATFORM:String = 'linux';
    #elseif mac
    static inline var PLATFORM:String = 'macos';
    #else
    static inline var PLATFORM:String = 'unknown';
    #end

    public static function reportUnlock(achievementId:String):Void {
        if (!ClientPrefs.data.serverConnection) {
            trace('[AchSync] Server connection disabled, queuing: $achievementId');
            _queue(achievementId);
            return;
        }

        if (!AuthManager.isLoggedIn) {
            _queue(achievementId);
            return;
        }

        _send(achievementId, false);
    }

    static function _send(achievementId:String, fromQueue:Bool):Void {
        if (!ClientPrefs.data.serverConnection) {
            trace('[AchSync] Server connection disabled, skipping send: $achievementId');
            if (!fromQueue) _queue(achievementId);
            return;
        }

        var token = SupabaseClient.getToken();
        if (token == '') {
            _queue(achievementId);
            return;
        }

        var bodyObj = {
            player_id: AuthManager.currentUserId,
            achievement_id: achievementId,
            game_version: GAME_VERSION,
            platform: PLATFORM
        };
        var body = Json.stringify(bodyObj);

        #if sys
        #if ios
        SupabaseClient.postAsync('/rest/v1/player_achievements', bodyObj, token, function(status:Int, data:String) {
            if (status >= 200 && status < 300) {
                trace('[AchSync] OK: $achievementId');
            } else {
                trace('[AchSync] Status $status: $achievementId');
                if (!fromQueue) _queue(achievementId);
            }
        }, ['Prefer' => 'resolution=ignore-duplicates']);
        #else
        sys.thread.Thread.create(function() {
            try {
                var http = new haxe.Http('${SupabaseClient.URL}/rest/v1/player_achievements');
                http.setHeader('apikey', SupabaseClient.ANON_KEY);
                http.setHeader('Authorization', 'Bearer $token');
                http.setHeader('Content-Type', 'application/json');
                http.setHeader('Prefer', 'resolution=ignore-duplicates');

                var status:Int = 0;
                var done:Bool = false;

                http.onStatus = function(s) { status = s; };
                http.onData = function(_) {
                    _mainThread(function() {
                        if (done) return;
                        done = true;
                        if (status >= 200 && status < 300) {
                            trace('[AchSync] OK: $achievementId');
                        } else {
                            trace('[AchSync] Status $status: $achievementId');
                            if (!fromQueue) _queue(achievementId);
                        }
                    });
                };
                http.onError = function(e) {
                    _mainThread(function() {
                        if (done) return;
                        done = true;
                        trace('[AchSync] Error: $achievementId -> $e');
                        if (!fromQueue) {
                            _queue(achievementId);
                            _showOfflineAlert(achievementId);
                        }
                    });
                };

                http.setPostData(body);
                http.request(true);
            } catch (e:Dynamic) {
                _mainThread(function() {
                    trace('[AchSync] Exception: $e');
                    if (!fromQueue) _queue(achievementId);
                });
            }
        });
        #end
        #end
    }

    static function _queue(id:String):Void {
        var q:Array<String> = _getQueue();
        if (q.indexOf(id) != -1) return;
        q.push(id);
        FlxG.save.data.achQueue = q;
        FlxG.save.flush();
        trace('[AchSync] Queued: $id (${q.length} pending)');
    }

    static function _getQueue():Array<String> {
        var q = FlxG.save.data.achQueue;
        if (q == null) return [];
        return q;
    }

    public static function flushQueue():Void {
        if (!ClientPrefs.data.serverConnection) {
            trace('[AchSync] Server connection disabled, skipping flush');
            return;
        }

        if (!AuthManager.isLoggedIn) return;

        var q:Array<String> = _getQueue();
        if (q.length == 0) return;

        trace('[AchSync] Flushing ${q.length} achievements...');

        var toSend = q.copy();
        FlxG.save.data.achQueue = [];
        FlxG.save.flush();

        for (id in toSend) {
            _send(id, true);
        }

        AlertMsg.show(
            'Başarımlar Gönderiliyor',
            '${toSend.length} başarım sunucuya gönderiliyor...',
            3,
            AlertMsg.COLOR_INFO
        );
    }

    static function _showOfflineAlert(achievementId:String):Void {
        #if ACHIEVEMENTS_ALLOWED
        var name:String = achievementId;
        if (Achievements.exists(achievementId)) {
            var ach = Achievements.get(achievementId);
            if (ach != null && ach.name != null)
                name = ach.name;
        }
        #else
        var name:String = achievementId;
        #end

        var start:Float = openfl.Lib.getTimer();
        var fired:Bool = false;

        FlxG.stage.addEventListener(openfl.events.Event.ENTER_FRAME, function alertCb(e:openfl.events.Event) {
            if (fired) return;
            if ((openfl.Lib.getTimer() - start) >= 4500) {
                fired = true;
                FlxG.stage.removeEventListener(openfl.events.Event.ENTER_FRAME, alertCb);
                AlertMsg.show(
                    'Sunucuya Kaydedilemedi',
                    '"$name" başarımı gönderilemedi.\nBağlantı kurulduğunda otomatik gönderilecektir.',
                    5,
                    AlertMsg.COLOR_ERROR
                );
            }
        });
    }

    static function _mainThread(func:Void->Void):Void {
        var cb:Dynamic = null;
        cb = function(_) {
            lime.app.Application.current.onUpdate.remove(cb);
            func();
        };
        lime.app.Application.current.onUpdate.add(cb);
    }
}