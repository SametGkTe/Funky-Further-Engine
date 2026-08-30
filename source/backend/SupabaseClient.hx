package backend;

import haxe.Json;
import haxe.crypto.Base64;
import haxe.io.Bytes;
import sys.io.File;
import sys.FileSystem;

class SupabaseClient {
    public static final URL = "https://ubhglndbbzidunjgnpqi.supabase.co";
    public static final ANON_KEY = "sb_publishable_xShtsNZot0C3cIDqj3s2Ew_V3zJs_1k";

    // ============================================
    // OBFUSCATION KEY (basit XOR şifreleme)
    // ============================================
    static inline var OBF_KEY:Int = 0x5A;

    // ============================================
    // TOKEN CACHE (her seferinde dosya okumamak için)
    // ============================================
    static var _cachedToken:String = null;
    static var _cachedUserId:String = null;
    static var _cachedRefreshToken:String = null;
    static var _cacheLoaded:Bool = false;

    // ============================================
    // DOSYA YOLU
    // ============================================
    static function _getAuthFilePath():String {
        var dir:String = "";
        try {
            dir = lime.system.System.applicationStorageDirectory;
        } catch (e) {
            dir = "./";
        }

        if (dir == null || dir == "")
            dir = "./";

        if (!StringTools.endsWith(dir, "/") && !StringTools.endsWith(dir, "\\"))
            dir += "/";

        return dir + "fe_auth.json";
    }

    // ============================================
    // XOR OBFUSCATION
    // ============================================
    static function _obfuscate(input:String):String {
        if (input == null || input == "")
            return "";

        var bytes = Bytes.ofString(input);
        var result = Bytes.alloc(bytes.length);

        for (i in 0...bytes.length) {
            result.set(i, bytes.get(i) ^ OBF_KEY);
        }

        return Base64.encode(result);
    }

    static function _deobfuscate(input:String):String {
        if (input == null || input == "")
            return "";

        try {
            var bytes = Base64.decode(input);
            var result = Bytes.alloc(bytes.length);

            for (i in 0...bytes.length) {
                result.set(i, bytes.get(i) ^ OBF_KEY);
            }

            return result.toString();
        } catch (e) {
            trace('[SupabaseClient] Deobfuscation failed: $e');
            return "";
        }
    }

    // ============================================
    // DOSYAYA KAYDET
    // ============================================
    static function _saveAuthFile():Void {
        try {
            var filePath = _getAuthFilePath();

            // Dizin yoksa oluştur
            var dir = haxe.io.Path.directory(filePath);
            if (dir != "" && dir != "." && !FileSystem.exists(dir)) {
                FileSystem.createDirectory(dir);
            }

            var data = {
                token: _obfuscate(_cachedToken != null ? _cachedToken : ""),
                refresh_token: _obfuscate(_cachedRefreshToken != null ? _cachedRefreshToken : ""),
                id: _cachedUserId != null ? _cachedUserId : ""
            };

            File.saveContent(filePath, Json.stringify(data));
            trace('[SupabaseClient] Auth saved to: $filePath');
        } catch (e) {
            trace('[SupabaseClient] Failed to save auth file: $e');
        }
    }

    // ============================================
    // DOSYADAN OKU
    // ============================================
    static function _loadAuthFile():Void {
        if (_cacheLoaded)
            return;

        _cacheLoaded = true;
        _cachedToken = "";
        _cachedUserId = "";
        _cachedRefreshToken = "";

        try {
            var filePath = _getAuthFilePath();

            if (!FileSystem.exists(filePath)) {
                trace('[SupabaseClient] No auth file found at: $filePath');
                return;
            }

            var content = File.getContent(filePath);

            if (content == null || content == "") {
                trace('[SupabaseClient] Auth file is empty');
                return;
            }

            var parsed = Json.parse(content);

            // Token (şifrelenmiş)
            var rawToken = Reflect.field(parsed, "token");
            if (rawToken != null && Std.string(rawToken) != "") {
                _cachedToken = _deobfuscate(Std.string(rawToken));
            }

            // Refresh token (şifrelenmiş)
            var rawRefresh = Reflect.field(parsed, "refresh_token");
            if (rawRefresh != null && Std.string(rawRefresh) != "") {
                _cachedRefreshToken = _deobfuscate(Std.string(rawRefresh));
            }

            // User ID (düz metin)
            var rawId = Reflect.field(parsed, "id");
            if (rawId != null) {
                _cachedUserId = Std.string(rawId);
            }

            trace('[SupabaseClient] Auth loaded from file, userId: $_cachedUserId, hasToken: ${_cachedToken != null && _cachedToken != ""}, hasRefresh: ${_cachedRefreshToken != null && _cachedRefreshToken != ""}');
        } catch (e) {
            trace('[SupabaseClient] Failed to load auth file: $e');
            _cachedToken = "";
            _cachedUserId = "";
            _cachedRefreshToken = "";
        }
    }

    // ============================================
    // PUBLIC API
    // ============================================

    public static function saveToken(token:String, userId:String):Void {
        _loadAuthFile();
        _cachedToken = token;
        _cachedUserId = userId;
        _saveAuthFile();
        trace('[SupabaseClient] Token saved for user: $userId');
    }

    public static function getToken():String {
        _loadAuthFile();
        return (_cachedToken != null) ? _cachedToken : "";
    }

    public static function getUserId():String {
        _loadAuthFile();
        return (_cachedUserId != null) ? _cachedUserId : "";
    }

    public static function saveRefreshToken(token:String):Void {
        _loadAuthFile();
        _cachedRefreshToken = token;
        _saveAuthFile();
        trace('[SupabaseClient] Refresh token saved');
    }

    public static function getRefreshToken():String {
        _loadAuthFile();
        return (_cachedRefreshToken != null) ? _cachedRefreshToken : "";
    }

    public static function hasToken():Bool {
        _loadAuthFile();
        return (_cachedToken != null && _cachedToken != "");
    }

    public static function clearToken():Void {
        _cachedToken = "";
        _cachedUserId = "";
        _cachedRefreshToken = "";
        _cacheLoaded = true;

        try {
            var filePath = _getAuthFilePath();
            if (FileSystem.exists(filePath)) {
                FileSystem.deleteFile(filePath);
                trace('[SupabaseClient] Auth file deleted');
            }
        } catch (e) {
            trace('[SupabaseClient] Failed to delete auth file: $e');
        }
    }

    // ============================================
    // HTTP - POST ASYNC
    // ============================================
    public static function postAsync(endpoint:String, body:Dynamic, token:String = "", callback:Int->String->Void, ?extraHeaders:Map<String, String>):Void {
        #if sys
        var fullUrl = '${URL}${endpoint}';
        trace("POST ASYNC -> " + fullUrl);
        #if ios
        requestIOS("POST", fullUrl, body != null ? haxe.Json.stringify(body) : null, token, extraHeaders, callback);
        #else
        sys.thread.Thread.create(function() {
            try {
                var http = new haxe.Http(fullUrl);
                http.setHeader("apikey", ANON_KEY);
                http.setHeader("Content-Type", "application/json");
                http.setHeader("Accept", "application/json");
                if (token != "") http.setHeader("Authorization", 'Bearer ${token}');
                if (extraHeaders != null) {
                    for (k in extraHeaders.keys()) http.setHeader(k, extraHeaders.get(k));
                }

                var responseStatus = 0;
                var responseDone = false;

                http.onData = function(d) {
                    if (responseStatus == 0) responseStatus = 200;
                    lime.app.Application.current.onUpdate.add(function(_) {
                        if (!responseDone) { responseDone = true; callback(responseStatus, d); }
                    });
                };
                http.onStatus = function(s) { responseStatus = s; };
                http.onError = function(e) {
                    lime.app.Application.current.onUpdate.add(function(_) {
                        if (!responseDone) { responseDone = true; callback(responseStatus, e); }
                    });
                };

                http.setPostData(haxe.Json.stringify(body));
                http.request(true);
            } catch(e:Dynamic) {
                callback(0, Std.string(e));
            }
        });
        #end
        #end
    }

    // ============================================
    // HTTP - GET ASYNC
    // ============================================
    public static function getAsync(endpoint:String, token:String = "", callback:Int->String->Void):Void {
        #if sys
        var fullUrl = '${URL}${endpoint}';
        trace("GET ASYNC -> " + fullUrl);
        #if ios
        requestIOS("GET", fullUrl, null, token, null, callback);
        #else
        sys.thread.Thread.create(function() {
            try {
                var http = new haxe.Http(fullUrl);
                http.setHeader("apikey", ANON_KEY);
                http.setHeader("Accept", "application/json");
                if (token != "") http.setHeader("Authorization", 'Bearer ${token}');

                var responseStatus = 0;
                var responseDone = false;

                http.onData = function(d) {
                    if (responseStatus == 0) responseStatus = 200;
                    lime.app.Application.current.onUpdate.add(function(_) {
                        if (!responseDone) { responseDone = true; callback(responseStatus, d); }
                    });
                };
                http.onStatus = function(s) { responseStatus = s; };
                http.onError = function(e) {
                    lime.app.Application.current.onUpdate.add(function(_) {
                        if (!responseDone) { responseDone = true; callback(responseStatus, e); }
                    });
                };

                http.request(false);
            } catch(e:Dynamic) {
                callback(0, Std.string(e));
            }
        });
        #end
        #end
    }

    #if ios
    static function requestIOS(methodStr:String, fullUrl:String, body:String, token:String, extraHeaders:Map<String, String>, callback:Int->String->Void):Void {
        try {
            var req = new lime.net.HTTPRequest<String>();
            req.timeout = 15000;
            req.method = methodStr;
            if (body != null) {
                req.contentType = "application/json";
                req.data = haxe.io.Bytes.ofString(body);
            }
            req.headers = [
                new lime.net.HTTPRequestHeader("apikey", ANON_KEY),
                new lime.net.HTTPRequestHeader("Accept", "application/json")
            ];
            if (token != "") req.headers.push(new lime.net.HTTPRequestHeader("Authorization", 'Bearer ${token}'));
            if (extraHeaders != null) {
                for (k in extraHeaders.keys()) req.headers.push(new lime.net.HTTPRequestHeader(k, extraHeaders.get(k)));
            }
            req.load(fullUrl).onComplete(function(d:String) {
                callback(req.responseStatus, d != null ? d : "");
            }).onError(function(e:Dynamic) {
                callback(req.responseStatus, Std.string(e));
            });
        } catch (e:Dynamic) {
            callback(0, Std.string(e));
        }
    }
    #end

    // ============================================
    // HTTP - POST SYNC
    // ============================================
    public static function post(endpoint:String, body:Dynamic, token:String = "", callback:Int->String->Void):Void {
        var fullUrl = '${URL}${endpoint}';
        trace("POST -> " + fullUrl);

        #if sys
        try {
            var http = new haxe.Http(fullUrl);
            http.setHeader("apikey", ANON_KEY);
            http.setHeader("Content-Type", "application/json");
            http.setHeader("Accept", "application/json");
            if (token != "") http.setHeader("Authorization", 'Bearer ${token}');

            var responseStatus = 0;

            http.onData = function(d) { callback(responseStatus, d); };
            http.onStatus = function(s) { responseStatus = s; };
            http.onError = function(e) { callback(0, e); };

            http.setPostData(haxe.Json.stringify(body));
            http.request(true);
        } catch(e:Dynamic) {
            callback(0, Std.string(e));
        }
        #end
    }

    // ============================================
    // HTTP - GET SYNC
    // ============================================
    public static function get(endpoint:String, token:String = "", callback:Int->String->Void):Void {
        var fullUrl = '${URL}${endpoint}';
        trace("GET -> " + fullUrl);

        #if sys
        try {
            var http = new haxe.Http(fullUrl);
            http.setHeader("apikey", ANON_KEY);
            http.setHeader("Accept", "application/json");
            if (token != "") http.setHeader("Authorization", 'Bearer ${token}');

            var responseStatus = 0;

            http.onData = function(d) { callback(responseStatus, d); };
            http.onStatus = function(s) { responseStatus = s; };
            http.onError = function(e) { callback(0, e); };

            http.request(false);
        } catch(e:Dynamic) {
            callback(0, Std.string(e));
        }
        #end
    }
}