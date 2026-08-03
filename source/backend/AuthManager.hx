package backend;

import objects.ProfileBox;

class AuthManager {
    public static var currentUsername:String = "Player";
    public static var currentUserId:String = "";
    public static var currentLevel:Int = 1;
    public static var currentScore:Int = 0;
    public static var currentAvatar:Int = 0;
    public static var currentCountry:String = "";
    public static var isLoggedIn:Bool = false;
    public static var currentUltraPoints:Float = 0.0;
    public static var currentRole:String = "player";
    public static var currentBadge:String = null;
    public static var currentAvatarUrl:String = null;

    // Ultra Streak
    public static var currentUltraStreak:Int = 0;
    public static var currentUltraStreakBest:Int = 0;
    public static var currentUltraStreakRequiredAcc:Float = 90.0;

    static function dynToFloat(v:Dynamic, ?def:Float = 0.0):Float {
        if (v == null) return def;
        if (Std.isOfType(v, Float)) return cast v;
        if (Std.isOfType(v, Int)) return cast v;
        var s:String = Std.string(v);
        var f = Std.parseFloat(s);
        return Math.isNaN(f) ? def : f;
    }

    static function dynToInt(v:Dynamic, ?def:Int = 0):Int {
        if (v == null) return def;
        if (Std.isOfType(v, Int)) return cast v;
        if (Std.isOfType(v, Float)) return Std.int(cast(v, Float));
        var s:String = Std.string(v);
        var i = Std.parseInt(s);
        return i == null ? def : i;
    }

    static function dynToString(v:Dynamic, ?def:String = ""):String {
        if (v == null) return def;
        return Std.string(v);
    }

    public static function getFullAvatarUrl(?bustCache:Bool = false):String {
        if (currentAvatarUrl == null || currentAvatarUrl.length == 0)
            return null;

        var url:String = null;

        if (StringTools.startsWith(currentAvatarUrl, "http"))
            url = currentAvatarUrl;
        else
            url = '${SupabaseClient.URL}/storage/v1/object/public/avatars/${currentUserId}/${currentAvatarUrl}';

        if (bustCache) {
            var sep = url.indexOf("?") == -1 ? "?" : "&";
            url += sep + "t=" + Std.string(Date.now().getTime());
        }

        return url;
    }

    public static function register(
        email:String, password:String,
        username:String, country:String,
        callback:Bool->String->Void
    ):Void {
        if (BadWordFilter.contains(username)) {
            callback(false, "Username contains inappropriate words.");
            return;
        }
        if (username.length < 4) {
            callback(false, "Username must be at least 4 characters.");
            return;
        }

        var body = {
            email: email,
            password: password,
            data: { username: username, country: country }
        };

        trace("SENDING BODY: " + haxe.Json.stringify(body));

        SupabaseClient.postAsync("/auth/v1/signup", body, "", function(status, data) {
            trace("REGISTER RESPONSE: " + data);

            if (status == 200 || status == 201) {
                try {
                    var parsed = haxe.Json.parse(data);

                    if (parsed.access_token != null) {
                        SupabaseClient.saveToken(parsed.access_token, parsed.user.id);
                        _saveRefreshFromParsed(parsed);
                        loadProfile(parsed.access_token, callback);
                    }
                    else if (parsed.id != null) {
                        callback(true, "Account created! Please check your email to verify.");
                    }
                    else {
                        callback(false, "Unexpected response.");
                    }
                } catch(e) {
                    callback(false, "Parse error: " + e);
                }
            } else {
                try {
                    var err = haxe.Json.parse(data);
                    callback(false, err.msg ?? err.error_description ?? err.error ?? "Registration failed.");
                } catch(_) {
                    callback(false, data);
                }
            }
        });
    }

    public static function loginWithUsername(
        username:String, password:String,
        callback:Bool->String->Void
    ):Void {
        var cleanUsername = StringTools.trim(username);

        SupabaseClient.postAsync(
            "/rest/v1/rpc/get_email_by_username",
            { p_username: cleanUsername },
            "",
            function(status:Int, data:String) {
                trace('[AuthManager] username RPC status=' + status + ' data=' + data);

                if (status < 200 || status >= 300) {
                    callback(false, 'Kullanıcı sorgusu başarısız. HTTP ' + status);
                    return;
                }

                try {
                    var parsed:Dynamic = haxe.Json.parse(data);

                    if (!Std.isOfType(parsed, Array)) {
                        callback(false, 'Beklenmeyen sunucu cevabı.');
                        return;
                    }

                    var arr:Array<Dynamic> = cast parsed;
                    if (arr.length == 0 || Reflect.field(arr[0], "email") == null) {
                        callback(false, "Kullanici bulunamadi.");
                        return;
                    }

                    var email:String = Std.string(Reflect.field(arr[0], "email"));
                    trace('[AuthManager] loginWithUsername resolved email=' + email);
                    login(email, password, callback);

                } catch (e:Dynamic) {
                    trace('[AuthManager] username RPC parse error: ' + e);
                    trace('[AuthManager] username RPC raw=' + data);
                    callback(false, "Baglanti hatasi.");
                }
            }
        );
    }

    public static function login(
        email:String, password:String,
        callback:Bool->String->Void
    ):Void {
        var body = {
            email: email,
            password: password,
            grant_type: "password"
        };

        trace("LOGIN BODY: " + haxe.Json.stringify(body));

        SupabaseClient.postAsync("/auth/v1/token?grant_type=password", body, "", function(status, data) {
            trace("LOGIN RESPONSE: " + data);
            if (data.indexOf('"access_token"') != -1) {
                var parsed = haxe.Json.parse(data);
                SupabaseClient.saveToken(parsed.access_token, parsed.user.id);
                _saveRefreshFromParsed(parsed);
                loadProfile(parsed.access_token, callback);
            } else {
                try {
                    var err = haxe.Json.parse(data);
                    callback(false, err.error_description ?? err.msg ?? err.error ?? "Invalid email or password.");
                } catch(_) {
                    callback(false, "Invalid email or password.");
                }
            }
        });
    }

    public static function autoLogin(callback:Bool->Void):Void {
        if (!SupabaseClient.hasToken()) {
            trace('[AuthManager] No saved token');
            callback(false);
            return;
        }

        var token = SupabaseClient.getToken();
        var userId = SupabaseClient.getUserId();

        trace('[AuthManager] Auto-login attempting... userId: $userId');

        if (userId == null || userId == '') {
            trace('[AuthManager] No saved userId');
            callback(false);
            return;
        }

        SupabaseClient.getAsync("/auth/v1/user", token, function(status:Int, data:String) {
            trace('[AuthManager] Auto-login /auth/v1/user: status=$status');

            if (status == 200 && data != null && data.indexOf('"id"') != -1) {
                trace('[AuthManager] Token valid, loading profile...');
                loadProfile(token, function(ok, msg) {
                    trace('[AuthManager] Auto-login loadProfile: $ok - $msg');
                    if (ok) {
                        #if ACHIEVEMENTS_ALLOWED
                        backend.AchievementSync.flushQueue();
                        #end
                    }
                    callback(ok);
                });
            } else {
                trace('[AuthManager] Token expired, trying refresh...');
                refreshAccessToken(function(refreshOk:Bool) {
                    if (refreshOk) {
                        var newToken = SupabaseClient.getToken();
                        trace('[AuthManager] Token refreshed, loading profile...');
                        loadProfile(newToken, function(ok, msg) {
                            trace('[AuthManager] Auto-login after refresh: $ok - $msg');
                            if (ok) {
                                #if ACHIEVEMENTS_ALLOWED
                                backend.AchievementSync.flushQueue();
                                #end
                            }
                            callback(ok);
                        });
                    } else {
                        trace('[AuthManager] Refresh failed, clearing auth, re-login required');
                        SupabaseClient.clearToken();
                        callback(false);
                    }
                });
            }
        });
    }

    public static function refreshAccessToken(callback:Bool->Void):Void {
        var refreshTk = SupabaseClient.getRefreshToken();

        if (refreshTk == null || refreshTk == "") {
            trace('[AuthManager] No refresh token available');
            callback(false);
            return;
        }

        trace('[AuthManager] Refreshing access token...');

        var body = {
            grant_type: "refresh_token",
            refresh_token: refreshTk
        };

        SupabaseClient.postAsync("/auth/v1/token?grant_type=refresh_token", body, "", function(status:Int, data:String) {
            trace('[AuthManager] Refresh response: status=$status');

            if (status == 200 && data != null && data.indexOf('"access_token"') != -1) {
                try {
                    var parsed = haxe.Json.parse(data);
                    var newToken:String = Reflect.field(parsed, "access_token");

                    if (newToken != null && newToken != "") {
                        var userId = SupabaseClient.getUserId();
                        var user = Reflect.field(parsed, "user");
                        if (user != null && Reflect.hasField(user, "id"))
                            userId = Std.string(Reflect.field(user, "id"));

                        SupabaseClient.saveToken(newToken, userId);
                        _saveRefreshFromParsed(parsed);

                        trace('[AuthManager] Token refreshed successfully!');
                        callback(true);
                        return;
                    }
                } catch (e) {
                    trace('[AuthManager] Refresh parse error: $e');
                }
            }

            trace('[AuthManager] Token refresh failed');
            callback(false);
        });
    }

    static function _saveRefreshFromParsed(parsed:Dynamic):Void {
        if (parsed == null) return;
        var rt = Reflect.field(parsed, "refresh_token");
        if (rt != null) {
            var rtStr = Std.string(rt);
            if (rtStr != "" && rtStr != "null") {
                SupabaseClient.saveRefreshToken(rtStr);
                trace('[AuthManager] Refresh token saved');
            }
        }
    }

    public static function forgotPassword(email:String, callback:Bool->String->Void):Void {
        SupabaseClient.postAsync("/auth/v1/recover", { email: email }, "", function(_, data) {
            callback(true, "Password reset email sent!");
        });
    }

    public static function deleteAccount(callback:Bool->String->Void):Void {
        var token = SupabaseClient.getToken();
        var userId = SupabaseClient.getUserId();
        var http = new haxe.Http('${SupabaseClient.URL}/rest/v1/profiles?id=eq.${userId}');
        http.setHeader("apikey", SupabaseClient.ANON_KEY);
        http.setHeader("Authorization", 'Bearer ${token}');
        http.setHeader("Content-Type", "application/json");
        http.onData = function(_) {
            logout();
            callback(true, "Account deleted.");
        };
        http.onError = function(e) callback(false, e);
        http.customRequest(false, new haxe.io.BytesOutput(), null, "DELETE");
    }

    public static function logout():Void {
        SupabaseClient.clearToken();
        currentUsername = "Player";
        currentUserId = "";
        currentLevel = 1;
        currentScore = 0;
        currentUltraPoints = 0.0;
        currentAvatar = 0;
        currentAvatarUrl = null;
        currentCountry = "";
        currentRole = "player";
        currentBadge = null;
        currentUltraStreak = 0;
        currentUltraStreakBest = 0;
        currentUltraStreakRequiredAcc = 90.0;
        isLoggedIn = false;
    }

    static function loadProfile(token:String, callback:Bool->String->Void):Void {
        SupabaseClient.getAsync(
            "/rest/v1/profiles?select=*&id=eq." + SupabaseClient.getUserId(),
            token,
            function(_, data) {
                try {
                    var arr:Array<Dynamic> = haxe.Json.parse(data);
                    if (arr.length > 0) {
                        var p = arr[0];
                        applyProfileData(p);

                        ProfileBox.syncFromAuth();

                        #if ACHIEVEMENTS_ALLOWED
                        AchievementSync.flushQueue();
                        #end

                        callback(true, "OK");
                    } else {
                        trace('[AuthManager] Profile not found, re-login required');
                        SupabaseClient.clearToken();
                        callback(false, "Profile not found");
                    }
                } catch(e) {
                    trace('[AuthManager] loadProfile parse error: $e');
                    SupabaseClient.clearToken();
                    callback(false, "Parse error");
                }
            }
        );
    }

    static function applyProfileData(p:Dynamic):Void {
        currentUsername     = dynToString(Reflect.field(p, "username"), "Player");
        currentUserId      = dynToString(Reflect.field(p, "id"), "");
        currentLevel       = dynToInt(Reflect.field(p, "level"), 1);
        currentScore       = dynToInt(Reflect.field(p, "total_score"), 0);
        currentAvatar      = dynToInt(Reflect.field(p, "avatar_id"), 0);
        currentCountry     = dynToString(Reflect.field(p, "country"), "");
        currentRole        = dynToString(Reflect.field(p, "role"), "player");

        // Avatar URL
        if (Reflect.hasField(p, "avatar_url") && Reflect.field(p, "avatar_url") != null) {
            currentAvatarUrl = dynToString(Reflect.field(p, "avatar_url"), null);
        } else {
            currentAvatarUrl = null;
        }

        if (Reflect.hasField(p, "badge"))
            currentBadge = Reflect.field(p, "badge") != null ? dynToString(Reflect.field(p, "badge"), null) : null;
        else
            currentBadge = null;

        if (Reflect.hasField(p, "ultra_points"))
            currentUltraPoints = dynToFloat(Reflect.field(p, "ultra_points"), 0.0);
        else if (Reflect.hasField(p, "ultraPoints"))
            currentUltraPoints = dynToFloat(Reflect.field(p, "ultraPoints"), 0.0);
        else if (Reflect.hasField(p, "up"))
            currentUltraPoints = dynToFloat(Reflect.field(p, "up"), 0.0);
        else if (Reflect.hasField(p, "ultrapoints"))
            currentUltraPoints = dynToFloat(Reflect.field(p, "ultrapoints"), 0.0);
        else
            currentUltraPoints = 0.0;

        // Ultra Streak
        if (Reflect.hasField(p, "ultra_streak_count"))
            currentUltraStreak = dynToInt(Reflect.field(p, "ultra_streak_count"), 0);
        else
            currentUltraStreak = 0;

        if (Reflect.hasField(p, "ultra_streak_best"))
            currentUltraStreakBest = dynToInt(Reflect.field(p, "ultra_streak_best"), 0);
        else
            currentUltraStreakBest = 0;

        if (Reflect.hasField(p, "ultra_streak_required_acc"))
            currentUltraStreakRequiredAcc = dynToFloat(Reflect.field(p, "ultra_streak_required_acc"), 90.0);
        else
            currentUltraStreakRequiredAcc = 90.0;

        isLoggedIn = true;

        trace('[AuthManager] Profile loaded -> username=$currentUsername'
            + ', level=$currentLevel'
            + ', score=$currentScore'
            + ', ultraPoints=$currentUltraPoints'
            + ', streak=$currentUltraStreak'
            + ', role=$currentRole'
            + ', badge=$currentBadge'
            + ', avatarUrl=$currentAvatarUrl');
    }

    static function tryParseError(data:String):String {
        try {
            var p = haxe.Json.parse(data);
            return p.msg ?? p.error_description ?? p.error ?? "Unknown error.";
        } catch(_) return "Unknown error.";
    }
}