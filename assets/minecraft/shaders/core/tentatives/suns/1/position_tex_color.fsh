// Big sun with ugly stars (tentative)

#version 150

const float PI = 3.141592654;
const float TAU = 6.283185307;

const float PLANET_RADIUS = 6371.0;
const float ATMOSPHERE_RADIUS = 6471.0;
const float ATMOSPHERE_HEIGHT = ATMOSPHERE_RADIUS - PLANET_RADIUS;

const vec3 RAYLEIGH_COEFF = vec3(5.8e-3, 13.5e-3, 33.1e-3);
const vec3 MIE_COEFF = vec3(21.0e-3);
const float MIE_DIRECTIVITY = 0.76;

const float RAYLEIGH_HEIGHT = 8.0;
const float MIE_HEIGHT = 1.2;

const vec3 ZENITH_DAY = vec3(0.0, 0.4, 0.8);
const vec3 HORIZON_DAY = vec3(0.5, 0.7, 1.0);
const vec3 ZENITH_NIGHT = vec3(0.0, 0.0, 0.08);
const vec3 HORIZON_NIGHT = vec3(0.05, 0.05, 0.2);
const vec3 ZENITH_SUNRISE = vec3(0.2, 0.2, 0.5);
const vec3 HORIZON_SUNRISE = vec3(0.9, 0.6, 0.4);
const vec3 ZENITH_SUNSET = vec3(0.2, 0.2, 0.5);
const vec3 HORIZON_SUNSET = vec3(0.9, 0.4, 0.2);

const int STAR_COUNT = 200;
const float STAR_INTENSITY = 0.8;

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

float hash(vec3 p) {
    p = fract(p * vec3(0.1031, 0.1030, 0.0973));
    p += dot(p, p.yxz + 33.33);
    return fract((p.x + p.y) * p.z);
}

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

float fbm(vec2 p, int octaves) {
    float value = 0.0;
    float amplitude = 0.5;
    float frequency = 1.0;

    for (int i = 0; i < octaves; i++) {
        value += amplitude * noise(p * frequency);
        amplitude *= 0.5;
        frequency *= 2.0;
    }

    return value;
}

float rayleighPhase(float cosTheta) {
    return 0.75 * (1.0 + cosTheta * cosTheta);
}

float miePhase(float cosTheta, float g) {
    float g2 = g * g;
    return (1.0 - g2) / pow(1.0 + g2 - 2.0 * g * cosTheta, 1.5) / (4.0 * PI);
}

float atmosphericDensity(float height, float scaleHeight) {
    return exp(-height / scaleHeight);
}

float opticalDepth(vec3 position, vec3 direction, float distance, float scaleHeight) {
    float sampleCount = 6.0;
    float stepSize = distance / sampleCount;
    float depth = 0.0;

    for (int i = 0; i < int(sampleCount); i++) {
        vec3 samplePos = position + direction * (float(i) + 0.5) * stepSize;
        float height = length(samplePos) - PLANET_RADIUS;
        float density = atmosphericDensity(height, scaleHeight);
        depth += density * stepSize;
    }

    return depth;
}

float timeToAngle(float time) {
    return fract(time) * TAU;
}

float stars(vec3 dir, float time) {
    float result = 0.0;

    vec2 uv = vec2(atan(dir.z, dir.x), asin(dir.y));
    uv *= 10.0; 

    vec2 gv = fract(uv) - 0.5;
    vec2 id = floor(uv);

    for (int y = -1; y <= 1; y++) {
        for (int x = -1; x <= 1; x++) {
            vec2 offset = vec2(x, y);

            float n = hash(id + offset);
            float size = fract(n * 6.21) * 0.2 + 0.05;

            float star = 1.0 - smoothstep(size * 0.5, size * 1.5, length(gv - offset + 0.5 - vec2(
                fract(n * 12.32), 
                fract(n * 27.53)
            )));

            float twinkle = sin(time * 5.0 + n * 10.0) * 0.5 + 0.5;
            twinkle = smoothstep(0.1, 0.6, twinkle);

            result += star * twinkle * STAR_INTENSITY * smoothstep(0.8, 0.9, n);
        }
    }

    return result;
}

float clouds(vec3 dir, float time) {

    vec2 uv = vec2(dir.x * 0.2 + time * 0.01, dir.z * 0.2);

    float cloudBase = fbm(uv, 5);
    float cloudDetail = fbm(uv * 3.0 + 1.5, 3);

    float cloud = smoothstep(0.4, 0.6, cloudBase) * cloudDetail;

    float heightMask = 1.0 - smoothstep(0.0, 0.3, abs(dir.y));

    return cloud * heightMask * smoothstep(-0.1, 0.1, dir.y);
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
    float currentTime = 1.0 - fract(atan(center.x, center.y) / PI * 0.5 + 0.5);

    mat4 projMat = ProjMat;
    projMat[3].xy = vec2(0.0);

    vec4 ndcPos = vec4(gl_FragCoord.xy / ScreenSize * 2.0 - 1.0, 0.0, 1.0);
    vec4 temp = inverse(projMat) * ndcPos;
    vec3 viewPos = temp.xyz / temp.w;
    vec3 rayDir = normalize(viewPos * mat3(ModelViewMat));

    vec3 sunDir = normalize(center);

    bool isDay = currentTime > 0.25 && currentTime < 0.75;
    bool isNight = currentTime < 0.2 || currentTime > 0.8;
    bool isSunrise = currentTime >= 0.2 && currentTime <= 0.25;
    bool isSunset = currentTime >= 0.75 && currentTime <= 0.8;

    float cosTheta = dot(rayDir, sunDir);

    vec3 skyColor;

    float verticalPos = rayDir.y * 0.5 + 0.5;

    float horizonFactor = pow(1.0 - abs(rayDir.y), 5.0);

    if (isDay) {

        skyColor = mix(HORIZON_DAY, ZENITH_DAY, smoothstep(0.0, 0.5, verticalPos));

        float rayleighStrength = 1.0 - exp(-1.0 / RAYLEIGH_HEIGHT);
        skyColor += RAYLEIGH_COEFF * rayleighPhase(cosTheta) * rayleighStrength;

        float sunGlare = miePhase(cosTheta, MIE_DIRECTIVITY) * 2.0;
        skyColor += vec3(1.0, 0.9, 0.7) * sunGlare;
    }
    else if (isNight) {

        skyColor = mix(HORIZON_NIGHT, ZENITH_NIGHT, smoothstep(0.0, 0.4, verticalPos));

        skyColor += vec3(1.0) * stars(rayDir, currentTime * 100.0);

        skyColor += vec3(0.1, 0.1, 0.3) * pow(1.0 - verticalPos, 8.0) * 0.2;
    }
    else if (isSunrise) {

        float t = (currentTime - 0.2) / 0.05; 

        vec3 horizonColor = mix(HORIZON_NIGHT, HORIZON_SUNRISE, t);
        vec3 zenithColor = mix(ZENITH_NIGHT, ZENITH_SUNRISE, t * t);

        skyColor = mix(horizonColor, zenithColor, smoothstep(0.0, 0.5, verticalPos));

        float sunRays = pow(max(0.0, cosTheta), 16.0);
        skyColor += vec3(1.0, 0.6, 0.3) * sunRays * t;

        skyColor += vec3(1.0) * stars(rayDir, currentTime * 100.0) * (1.0 - t);
    }
    else { 

        float t = (currentTime - 0.75) / 0.05; 

        vec3 horizonColor = mix(HORIZON_DAY, HORIZON_SUNSET, t);
        vec3 zenithColor = mix(ZENITH_DAY, ZENITH_SUNSET, t);

        skyColor = mix(horizonColor, zenithColor, smoothstep(0.0, 0.5, verticalPos));

        float sunRays = pow(max(0.0, cosTheta), 16.0);
        skyColor += vec3(1.0, 0.4, 0.2) * sunRays * 2.0;

        skyColor += vec3(1.0) * stars(rayDir, currentTime * 100.0) * t;
    }

    float cloudAmount = clouds(rayDir, currentTime);

    vec3 cloudColor;
    if (isDay) {
        cloudColor = vec3(1.0);
    } else if (isNight) {
        cloudColor = vec3(0.1, 0.1, 0.2); 
    } else if (isSunrise) {
        float t = (currentTime - 0.2) / 0.05;
        cloudColor = mix(vec3(0.1, 0.1, 0.2), vec3(1.0, 0.7, 0.4), t); 
    } else { 
        float t = (currentTime - 0.75) / 0.05;
        cloudColor = mix(vec3(1.0), vec3(1.0, 0.5, 0.2), t); 
    }

    if (!isNight) {
        float cloudLight = pow(max(0.0, dot(vec3(0.0, 1.0, 0.0), sunDir)), 2.0);
        cloudColor *= max(0.2, cloudLight);
    }

    skyColor = mix(skyColor, cloudColor, cloudAmount * 0.8);

    float sunDisk = smoothstep(0.9997, 0.9999, cosTheta);
    vec3 sunColor;

    if (isDay) {
        sunColor = vec3(1.0, 0.95, 0.9) * 2.0;
    } else if (isNight) {
        sunDisk = 0.0; 
    } else if (isSunrise) {
        float t = (currentTime - 0.2) / 0.05;
        sunColor = mix(vec3(1.0, 0.5, 0.2), vec3(1.0, 0.95, 0.9), t) * 2.0;
    } else { 
        float t = (currentTime - 0.75) / 0.05;
        sunColor = mix(vec3(1.0, 0.95, 0.9), vec3(1.0, 0.5, 0.2), t) * 2.0;
    }

    skyColor = mix(skyColor, sunColor, sunDisk);

    fragColor = vec4(skyColor, 1.0);
}