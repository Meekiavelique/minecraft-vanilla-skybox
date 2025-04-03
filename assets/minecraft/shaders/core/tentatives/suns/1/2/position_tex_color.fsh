// Pretty accurate sun and sky color with non-working stars

#version 150

const float PI = 3.141592654;
const float EPSILON = 1e-6;

const vec3 BETA_R = vec3(5.8, 13.5, 33.1) * 1e-6;
const float BETA_M = 3.996e-6;
const float H_R = 8.0;
const float H_M = 1.2;
const float G = 0.8;

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
    f = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);

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

    for (int i = 0; i < 4; i++) {
        value += amplitude * noise(p * frequency);
        amplitude *= 0.5;
        frequency *= 2.0;
    }

    return value;
}

float rayleighPhase(float mu) {
    return (3.0 / (16.0 * PI)) * (1.0 + mu * mu);
}

float miePhase(float mu) {
    float g2 = G * G;
    return (3.0 / (8.0 * PI)) * ((1.0 - g2) * (1.0 + mu * mu)) / 
           (pow(1.0 + g2 - 2.0 * G * mu, 1.5) * (2.0 + g2));
}

float atmosphericDensity(float h, float scale) {
    return exp(-max(0.0, h) / scale);
}

vec3 skyColor(vec3 dir, vec3 sunDir, float time) {
    float mu = dot(dir, sunDir);
    float sunMu = clamp(mu, 0.0, 1.0);
    float zenith = max(0.0, dir.y);
    
    float rayleighAmount = atmosphericDensity(1.0 - zenith, H_R);
    float mieAmount = atmosphericDensity(1.0 - zenith, H_M);
    
    float rayleighFactor = rayleighPhase(mu);
    float mieFactor = miePhase(mu);
    
    vec3 betaR = BETA_R * rayleighAmount;
    vec3 betaM = vec3(BETA_M) * mieAmount;
    
    vec3 sunLight = vec3(1.0, 0.95, 0.9);
    vec3 skyLuminance = vec3(0.0);
    
    if (time > 0.25 && time < 0.75) {
        float intensity = 1.0;
        if (time > 0.65) intensity = 1.0 - (time - 0.65) * 10.0;
        if (time < 0.35) intensity = (time - 0.25) * 10.0;
        
        skyLuminance = (betaR * rayleighFactor + betaM * mieFactor) * intensity;
        skyLuminance += pow(sunMu, 128.0) * 5.0 * vec3(1.0, 0.9, 0.6) * intensity;
    }
    
    bool isNight = time < 0.2 || time > 0.8;
    bool isSunriseOrSunset = (time >= 0.2 && time <= 0.3) || (time >= 0.7 && time <= 0.8);
    
    vec3 baseColor;
    
    if (isNight) {
        float moonMu = clamp(dot(dir, -sunDir), 0.0, 1.0);
        baseColor = vec3(0.01, 0.01, 0.04) + zenith * vec3(0.0, 0.0, 0.05);
        baseColor += pow(moonMu, 32.0) * 0.1 * vec3(0.6, 0.7, 1.0);
    } else if (isSunriseOrSunset) {
        float t = 0.0;
        if (time >= 0.2 && time <= 0.3) t = (time - 0.2) * 10.0;
        if (time >= 0.7 && time <= 0.8) t = 1.0 - (time - 0.7) * 10.0;
        
        vec3 horizonColor = mix(vec3(0.1, 0.1, 0.2), vec3(1.0, 0.6, 0.2), t);
        vec3 zenithColor = mix(vec3(0.02, 0.02, 0.1), vec3(0.2, 0.4, 0.8), t);
        
        baseColor = mix(zenithColor, horizonColor, pow(1.0 - zenith, 4.0));
        baseColor += pow(sunMu, 8.0) * vec3(1.0, 0.6, 0.3) * t;
    } else {
        skyLuminance += vec3(0.2, 0.5, 1.0) * (1.0 - pow(zenith, 0.5)) * 0.2;
    }
    
    vec3 result = skyLuminance + baseColor;
    
    if (isNight) {
        vec2 starCoord = vec2(atan(dir.z, dir.x), asin(dir.y)) * 20.0;
        float starNoise = fbm(starCoord);
        
        float timeFactor = time * 100.0;
        float twinkle = 0.8 + 0.2 * sin(timeFactor + starNoise * 100.0);
        
        if (starNoise > 0.97) {
            float starValue = smoothstep(0.97, 0.99, starNoise) * twinkle;
            result += vec3(0.8, 0.9, 1.0) * starValue;
        }
    }
    
    float cloudAmount = fbm(vec2(dir.x * 0.1 + time * 0.01, dir.z * 0.1));
    float cloudDetail = fbm(vec2(dir.x * 0.5 + time * 0.02, dir.z * 0.5)) * 0.5;
    float clouds = smoothstep(0.4, 0.6, cloudAmount) * cloudDetail * smoothstep(0.0, 0.4, zenith);
    
    vec3 cloudColor = vec3(1.0);
    if (isNight) cloudColor = vec3(0.3, 0.3, 0.5) * 0.2;
    if (isSunriseOrSunset) cloudColor = mix(vec3(0.7), vec3(1.0, 0.6, 0.3), pow(sunMu, 2.0));
    
    result = mix(result, cloudColor, clouds * 0.5);
    
    return result;
}

void main() {
    if (isSun < 0.5) {
        vec4 color = texture(Sampler0, texCoord0) * vertexColor;
        if (color.a == 0.0) discard;
        fragColor = color * ColorModulator;
        return;
    }

    if (gl_PrimitiveID >= 1) discard;

    vec3 center = (vertex1.xyz / vertex1.w + vertex3.xyz / vertex3.w) * 0.5;
    
    mat4 projMat = ProjMat;
    projMat[3].xy = vec2(0.0);

    vec4 ndcPos = vec4(gl_FragCoord.xy / ScreenSize * 2.0 - 1.0, 0.0, 1.0);
    vec4 temp = inverse(projMat) * ndcPos;
    vec3 viewPos = temp.xyz / temp.w;
    vec3 worldDir = normalize(viewPos * mat3(ModelViewMat));

    float currentTime = 1.0 - fract(atan(center.x, center.y) / PI * 0.5 + 0.5);
    vec3 sunDir = normalize(center);
    
    vec3 color = skyColor(worldDir, sunDir, currentTime);
    
    fragColor = vec4(color, 1.0);
}