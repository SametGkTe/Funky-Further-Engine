package shaders;

import flixel.FlxBasic;

class WarpEffect extends FlxBasic {
    var shader:WarpShader;

    public function new(sprite:FlxSprite):Void {
        super();
        sprite.shader = this.shader = new WarpShader();
        shader.iTime.value = [0];
    }

    override function update(elapsed:Float):Void {
        super.update(elapsed);
        shader.iTime.value[0] += elapsed;
    }
}

class WarpShader extends FlxShader {
    @:glFragmentSource('
    // Optimized version of the Flaring shader by HomuHomu833
    // Flaring by nimitz (twitter: @stormoid)
    // https://www.shadertoy.com/view/lsSGzy
    // License Creative Commons Attribution-NonCommercial-ShareAlike 3.0 Unported License
    // Contact the author for other licensing options

    #pragma header
    uniform float iTime;
    #define iChannel0 bitmap
    #define texture flixel_texture2D
    #define fragColor gl_FragColor
    #define mainImage main

    //change this value (1 to 5) or tweak the settings yourself.
    //the gamma and spot brightness parameters can use negative values
    #define TYPE 4

    #if TYPE == 1
        #define brightness 1.
        #define ray_brightness 11.
        #define gamma 5.
        #define spot_brightness 4.
        #define ray_density 1.5
        #define curvature .1
        #define red 7.
        #define green 1.3
        #define blue  1.
        //1 -> ridged, 2 -> sinfbm, 3 -> pure fbm
        #define noisetype 2
        #define sin_freq 50. //for type 2
    #elif TYPE == 2
        #define brightness 1.5
        #define ray_brightness 10.
        #define gamma 8.
        #define spot_brightness 15.
        #define ray_density 3.5
        #define curvature 15.
        #define red 4.
        #define green 1.
        #define blue .1
        #define noisetype 1
        #define sin_freq 13.
    #elif TYPE == 3
        #define brightness 1.5
        #define ray_brightness 20.
        #define gamma 4.
        #define spot_brightness .95
        #define ray_density 3.14
        #define curvature 17.
        #define red 2.9
        #define green .7
        #define blue 3.5
        #define noisetype 2
        #define sin_freq 15.
    #elif TYPE == 4
        #define brightness 2.
        #define ray_brightness 4.
        #define gamma 6.
        #define spot_brightness 0.
        #define ray_density 6.5
        #define curvature 70.
        #define red 2.9
        #define green .7
        #define blue 3.5
        #define noisetype 1
        #define sin_freq 6.
        #define YO_DAWG
    #elif TYPE == 5
        #define brightness 2.
        #define ray_brightness 5.
        #define gamma 5.
        #define spot_brightness 1.7
        #define ray_density 30.
        #define curvature 1.
        #define red 1.
        #define green 4.0
        #define blue 4.9
        #define noisetype 2
        #define sin_freq 5. //for type 2
    #endif

    #define PROCEDURAL_NOISE
    //#define YO_DAWG

    float hash(float n) {
        return fract(sin(n) * 43758.5453);
    }

    float noise(vec2 x) {
        #ifdef PROCEDURAL_NOISE
        x *= 1.75;
        vec2 p = floor(x);
        vec2 f = fract(x);
        f = f * f * (3.0 - 2.0 * f);
        float n = p.x + p.y * 57.0;
        return mix(mix(hash(n + 0.0), hash(n + 1.0), f.x),
                   mix(hash(n + 57.0), hash(n + 58.0), f.x), f.y);
        #else
        return texture(iChannel0, x * 0.01).x;
        #endif
    }

    float fbm(vec2 p) {
        float z = 2.0;
        float rz = 0.0;
        p *= 0.25;
        #ifdef GL_ES
        float noising = 4.0;
        #else
        float noising = 6.0;
        #endif
        for (float i = 1.0; i < noising; i++) {
            #if noisetype == 1
            rz += abs((noise(p) - 0.5) * 2.0) / z;
            #elif noisetype == 2
            rz += (sin(noise(p) * sin_freq) * 0.5 + 0.5) / z;
            #else
            rz += noise(p) / z;
            #endif
            z *= 2.0;
            p *= 2.0 * mat2(0.80, 0.60, -0.60, 0.80);
        }
        return rz;
    }

    void mainImage() {
        vec2 fragCoord = openfl_TextureCoordv * openfl_TextureSize;
        vec2 iResolution = openfl_TextureSize;
        float t = -iTime * 0.03;
        vec2 uv = fragCoord.xy / iResolution.xy - 0.5;
        uv.x *= iResolution.x / iResolution.y;
        uv *= curvature * 0.05 + 0.0001;

        float r = length(uv);
        vec2 norm_uv = normalize(uv);
        float x = dot(norm_uv, vec2(0.5, 0.0)) + t;
        float y = dot(norm_uv, vec2(0.0, 0.5)) + t;

        #ifdef YO_DAWG
        x = fbm(vec2(y * ray_density * 0.5, r + x * ray_density * 0.2));
        y = fbm(vec2(r + y * ray_density * 0.1, x * ray_density * 0.5));
        #endif

        float val = fbm(vec2(r + y * ray_density, r + x * ray_density - y));
        val = smoothstep(gamma * 0.02 - 0.1, ray_brightness + gamma * 0.02 - 0.1 + 0.001, val);
        val = sqrt(val);

        vec3 col = val / vec3(red, green, blue);
        col = clamp(1.0 - col, 0.0, 1.0);
        col = mix(col, vec3(1.0), spot_brightness - r / 0.1 / curvature * 200.0 / brightness);
        col = clamp(col, 0.0, 1.0);
        col = pow(col, vec3(1.7));

        fragColor = vec4(col * 0.15, 0.3);
    }
    ')
    public function new() {
        super();
    }
}