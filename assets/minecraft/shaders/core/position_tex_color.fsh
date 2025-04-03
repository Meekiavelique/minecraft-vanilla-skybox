#version 150

const float PI = 3.141592654;

const vec3 DAY_HORIZON = vec3(0.5, 0.7, 1.0);
const vec3 DAY_ZENITH = vec3(0.0, 0.4, 0.8);
const vec3 NIGHT_HORIZON = vec3(0.05, 0.05, 0.15);
const vec3 NIGHT_ZENITH = vec3(0.0, 0.0, 0.05);
const vec3 SUNSET_HORIZON = vec3(0.9, 0.5, 0.2);
const vec3 SUNSET_ZENITH = vec3(0.2, 0.2, 0.5);

const float DAY_START = 0.25;
const float DAY_END = 0.75;
const float NIGHT_START = 0.8;
const float NIGHT_END = 0.2;

uniform sampler2D Sampler0;
uniform vec4 ColorModulator;
uniform mat4 ModelViewMat;
uniform mat4 ProjMat;
uniform vec2 ScreenSize;

in vec2 texCoord0;
in vec4 vertexColor;
in float isSun;
in vec4 vertex1;
in vec4 vertex2;
in vec4 vertex3;

out vec4 fragColor;

float hash(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);

    float a = hash(i);
    float b = hash(i + vec2(1.0, 0.0));
    float c = hash(i + vec2(0.0, 1.0));
    float d = hash(i + vec2(1.0, 1.0));

    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
    float value = 0.0;
    float amplitude = 0.5;
    float frequency = 1.0;

    for (int i = 0; i < 3; i++) {
        value += amplitude * noise(p * frequency);
        amplitude *= 0.5;
        frequency *= 2.0;
    }

    return value;
}

void main() {
    if (isSun < 0.5) {
        vec4 color = texture(Sampler0, texCoord0) * vertexColor;
        if (color.a == 0.0) {
            discard;
        }
        fragColor = color * ColorModulator;
        return;
    }

    if (gl_PrimitiveID >= 1) {
        discard;
    }

    vec3 center = (vertex1.xyz / vertex1.w + vertex3.xyz / vertex3.w) * 0.5;

    mat4 projMat = ProjMat;
    projMat[3].xy = vec2(0.0);

    vec4 ndcPos = vec4(gl_FragCoord.xy / ScreenSize * 2.0 - 1.0, 0.0, 1.0);
    vec4 temp = inverse(projMat) * ndcPos;
    vec3 viewPos = temp.xyz / temp.w;
    vec3 rayDir = normalize(viewPos * mat3(ModelViewMat));

    float upFactor = rayDir.y * 0.5 + 0.5;

    float currentTime = 1.0 - fract(atan(center.x, center.y) / PI * 0.5 + 0.5);

    bool isDay = currentTime > DAY_START && currentTime < DAY_END;
    bool isNight = currentTime < NIGHT_END || currentTime > NIGHT_START;
    bool isSunrise = currentTime >= NIGHT_END && currentTime <= DAY_START;
    bool isSunset = currentTime >= DAY_END && currentTime <= NIGHT_START;

    vec3 skyColor;

    if (isDay) {
        skyColor = mix(DAY_HORIZON, DAY_ZENITH, smoothstep(0.0, 1.0, upFactor));
    } 
    else if (isNight) {
        skyColor = mix(NIGHT_HORIZON, NIGHT_ZENITH, smoothstep(0.0, 1.0, upFactor));

        vec2 noiseUV = vec2(atan(rayDir.z, rayDir.x), asin(rayDir.y)) * 20.0;
        float noise = fbm(noiseUV);
        if (noise > 0.97) {
            skyColor += vec3(0.6, 0.7, 0.8) * smoothstep(0.97, 0.99, noise);
        }
    } 
    else if (isSunrise) {
        float t = (currentTime - NIGHT_END) / (DAY_START - NIGHT_END);

        vec3 sunriseHorizon = mix(vec3(1.0, 0.5, 0.1), vec3(1.0, 0.7, 0.3), t);
        vec3 sunriseZenith = mix(NIGHT_ZENITH, DAY_ZENITH, t * t);

        float horizonFactor = pow(1.0 - upFactor, 4.0);
        skyColor = mix(sunriseZenith, sunriseHorizon, horizonFactor);
    } 
    else { 
        float t = (currentTime - DAY_END) / (NIGHT_START - DAY_END);

        vec3 sunsetHorizon = mix(vec3(1.0, 0.6, 0.2), vec3(0.9, 0.3, 0.1), t);
        vec3 sunsetZenith = mix(DAY_ZENITH, NIGHT_ZENITH, t * t);

        float horizonFactor = pow(1.0 - upFactor, 4.0);
        skyColor = mix(sunsetZenith, sunsetHorizon, horizonFactor);
    }

    float rayleighFactor = 1.0 - pow(rayDir.y * 0.5 + 0.5, 3.0);
    vec3 rayleighColor = vec3(0.1, 0.2, 0.4);
    skyColor = mix(skyColor, rayleighColor, rayleighFactor * 0.2);

    vec2 cloudUV = vec2(rayDir.x * 0.1 + currentTime * 0.01, rayDir.z * 0.1);
    float cloud = fbm(cloudUV) * max(0.0, rayDir.y + 0.1) * 0.1;
    skyColor = mix(skyColor, vec3(1.0), cloud);

    fragColor = vec4(skyColor, 1.0);
}