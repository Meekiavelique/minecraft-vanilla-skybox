// Atmospheric Scattering Sky
// https://www.scratchapixel.com/lessons/procedural-generation-virtual-worlds/simulating-sky/simulating-colors-of-the-sky.html
// https://github.com/wwwtyro/glsl-atmosphere

#version 150

const float PI = 3.14159265359;
const float ONE_OVER_FOURPI = 0.07957747154;
const float EPSILON = 1e-6;

const vec3 BETA_RAYLEIGH = vec3(5.5e-6, 13.0e-6, 22.4e-6); 
const float BETA_MIE = 21e-6;
const float MIE_G = 0.76; 
const float MIE_G2 = MIE_G * MIE_G;

const float RAYLEIGH_SCALE_HEIGHT = 8000.0;
const float MIE_SCALE_HEIGHT = 1200.0;

const float PLANET_RADIUS = 6371000.0;
const float ATMOSPHERE_RADIUS = 6471000.0;

const int PRIMARY_SAMPLE_COUNT = 16;
const int LIGHT_SAMPLE_COUNT = 8;

const vec3 NIGHT_ZENITH = vec3(0.01, 0.01, 0.08);  
const vec3 NIGHT_HORIZON = vec3(0.05, 0.05, 0.1);  
const float STAR_DENSITY = 0.97;
const vec3 NEBULA_COLOR_1 = vec3(0.5, 0.1, 0.4);   
const vec3 NEBULA_COLOR_2 = vec3(0.1, 0.2, 0.6);   

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
    return fract(p.x * p.y * (p.x + p.y));
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

float fbm(vec2 p, int octaves) {
    float value = 0.0;
    float amplitude = 0.5;
    float frequency = 1.0;

    for (int i = 0; i < octaves; i++) {
        value += amplitude * noise(p * frequency);
        amplitude *= 0.5;
        frequency *= 2.0;
        if (i >= 5) break; 
    }

    return value;
}

vec3 starField(vec3 dir, float time) {

    float theta = atan(dir.z, dir.x);
    float phi = acos(dir.y);

    vec2 starCoord = vec2(theta / (2.0 * PI) + 0.5, phi / PI);
    starCoord *= 400.0;  

    float n1 = noise(starCoord);
    float n2 = noise(starCoord * 1.5 + 10.0);
    float n3 = noise(starCoord * 2.0 + 20.0);

    vec3 stars = vec3(0.0);

    if (n1 > STAR_DENSITY + 0.025) {
        float brightness = (n1 - STAR_DENSITY - 0.025) * 40.0;
        vec3 starColor = vec3(1.0, 0.9, 0.9); 
        stars += starColor * brightness;
    }

    if (n2 > STAR_DENSITY + 0.015) {
        float brightness = (n2 - STAR_DENSITY - 0.015) * 20.0;
        vec3 starColor = vec3(0.9, 0.9, 1.0); 
        stars += starColor * brightness;
    }

    if (n3 > STAR_DENSITY + 0.010) {
        float brightness = (n3 - STAR_DENSITY - 0.010) * 10.0;
        vec3 starColor = mix(vec3(0.8, 0.9, 1.0), vec3(1.0, 0.8, 0.7), noise(starCoord * 0.5)); 
        stars += starColor * brightness;
    }

    stars *= 0.9 + 0.2 * sin(time * 0.1 + noise(starCoord) * 10.0);

    return stars;
}

vec3 nebulaEffect(vec3 dir, float time) {

    float theta = atan(dir.z, dir.x);
    float phi = acos(dir.y);

    vec2 nebulaCoord = vec2(theta / (2.0 * PI) + 0.5, phi / PI);

    float pattern1 = fbm(nebulaCoord * 4.0 + time * 0.01, 5);
    float pattern2 = fbm(nebulaCoord * 2.0 + vec2(100.0) + time * 0.005, 5);

    float mask = smoothstep(0.4, 0.6, fbm(nebulaCoord * 1.0, 3));

    vec3 nebulaColor = mix(NEBULA_COLOR_1, NEBULA_COLOR_2, pattern2);

    return nebulaColor * pattern1 * mask * 0.15;
}

vec2 raySphereIntersect(vec3 rayOrigin, vec3 rayDir, float sphereRadius) {
    float a = dot(rayDir, rayDir);
    float b = 2.0 * dot(rayDir, rayOrigin);
    float c = dot(rayOrigin, rayOrigin) - (sphereRadius * sphereRadius);
    float d = b * b - 4.0 * a * c;

    if (d < 0.0) return vec2(1e5, -1e5);

    float sqrtD = sqrt(d);
    return vec2(
        (-b - sqrtD) / (2.0 * a),
        (-b + sqrtD) / (2.0 * a)
    );
}

float rayleighPhase(float cosTheta) {
    return 0.75 * ONE_OVER_FOURPI * (1.0 + cosTheta * cosTheta);
}

float miePhase(float cosTheta) {
    return 3.0 * ONE_OVER_FOURPI * (1.0 - MIE_G2) * (1.0 + cosTheta * cosTheta) / 
           (2.0 * (2.0 + MIE_G2) * pow(1.0 + MIE_G2 - 2.0 * MIE_G * cosTheta, 1.5));
}

vec3 computeScattering(vec3 rayOrigin, vec3 rayDir, vec3 sunDir, float sunIntensity) {

    rayDir = normalize(rayDir);
    sunDir = normalize(sunDir);

    vec2 planetIntersection = raySphereIntersect(rayOrigin, rayDir, PLANET_RADIUS);
    vec2 atmosphereIntersection = raySphereIntersect(rayOrigin, rayDir, ATMOSPHERE_RADIUS);

    if (atmosphereIntersection.x > atmosphereIntersection.y) return vec3(0.0);

    float tMax = atmosphereIntersection.y;
    if (planetIntersection.x > 0.0 && planetIntersection.x < tMax) {
        tMax = planetIntersection.x;
    }

    float tMin = max(0.0, atmosphereIntersection.x);

    float stepSize = (tMax - tMin) / float(PRIMARY_SAMPLE_COUNT);

    vec3 totalRayleigh = vec3(0.0);
    vec3 totalMie = vec3(0.0);
    float opticalDepthRayleigh = 0.0;
    float opticalDepthMie = 0.0;

    float mu = dot(rayDir, sunDir);

    float phaseRayleigh = rayleighPhase(mu);
    float phaseMie = miePhase(mu);

    float currentT = tMin;

    for (int i = 0; i < PRIMARY_SAMPLE_COUNT; i++) {

        vec3 samplePosition = rayOrigin + rayDir * (currentT + stepSize * 0.5);

        float height = length(samplePosition) - PLANET_RADIUS;

        float densityFactorRayleigh = exp(-height / RAYLEIGH_SCALE_HEIGHT) * stepSize;
        float densityFactorMie = exp(-height / MIE_SCALE_HEIGHT) * stepSize;

        opticalDepthRayleigh += densityFactorRayleigh;
        opticalDepthMie += densityFactorMie;

        vec2 lightIntersection = raySphereIntersect(samplePosition, sunDir, ATMOSPHERE_RADIUS);
        float lightStepSize = lightIntersection.y / float(LIGHT_SAMPLE_COUNT);

        float lightOpticalDepthRayleigh = 0.0;
        float lightOpticalDepthMie = 0.0;

        for (int j = 0; j < LIGHT_SAMPLE_COUNT; j++) {

            vec3 lightSamplePosition = samplePosition + sunDir * (float(j) + 0.5) * lightStepSize;

            float lightSampleHeight = length(lightSamplePosition) - PLANET_RADIUS;

            if (lightSampleHeight < 0.0) break;

            lightOpticalDepthRayleigh += exp(-lightSampleHeight / RAYLEIGH_SCALE_HEIGHT) * lightStepSize;
            lightOpticalDepthMie += exp(-lightSampleHeight / MIE_SCALE_HEIGHT) * lightStepSize;
        }

        vec3 attenuation;
        attenuation.x = exp(-(BETA_RAYLEIGH.x * (opticalDepthRayleigh + lightOpticalDepthRayleigh) +
                            BETA_MIE * 1.1 * (opticalDepthMie + lightOpticalDepthMie)));
        attenuation.y = exp(-(BETA_RAYLEIGH.y * (opticalDepthRayleigh + lightOpticalDepthRayleigh) +
                            BETA_MIE * 1.1 * (opticalDepthMie + lightOpticalDepthMie)));
        attenuation.z = exp(-(BETA_RAYLEIGH.z * (opticalDepthRayleigh + lightOpticalDepthRayleigh) +
                            BETA_MIE * 1.1 * (opticalDepthMie + lightOpticalDepthMie)));

        totalRayleigh += densityFactorRayleigh * attenuation;
        totalMie += densityFactorMie * attenuation;

        currentT += stepSize;
    }

    return sunIntensity * (
        totalRayleigh * BETA_RAYLEIGH * phaseRayleigh +
        totalMie * BETA_MIE * phaseMie
    );
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

    float currentTime = 0.0;
    vec3 pos = vertex1.xyz / vertex1.w;
    currentTime = 1.0 - fract(atan(pos.x, pos.y) / PI * 0.5 + 0.5);

    vec4 ndcPos = vec4(gl_FragCoord.xy / ScreenSize * 2.0 - 1.0, 0.0, 1.0);
    vec4 temp = inverse(ProjMat) * ndcPos;
    vec3 viewPos = temp.xyz / temp.w;
    vec3 rayDir = normalize(viewPos * mat3(ModelViewMat));

    vec3 sunDir = normalize(vec3(cos((currentTime - 0.5) * PI * 2.0), sin((currentTime - 0.5) * PI), 0.0));

    bool isDay = currentTime > 0.25 && currentTime < 0.75;
    bool isNight = currentTime < 0.2 || currentTime > 0.8;
    bool isSunrise = currentTime >= 0.2 && currentTime <= 0.3;
    bool isSunset = currentTime >= 0.7 && currentTime <= 0.8;

    float sunIntensity = 22.0;
    if (isSunrise || isSunset) {
        float t = isSunrise ? (currentTime - 0.2) / 0.1 : (currentTime - 0.7) / 0.1;
        sunIntensity *= mix(0.5, 1.0, t);
    } else if (isNight) {
        sunIntensity *= 0.01; 
    }

    vec3 origin = vec3(0.0, PLANET_RADIUS + 1.0, 0.0); 
    vec3 scatteredLight = computeScattering(origin, rayDir, sunDir, sunIntensity);

    vec3 skyColor = 1.0 - exp(-scatteredLight);

    if (isNight || isSunrise || isSunset) {

        float nightBlend = isNight ? 1.0 : 
                          isSunrise ? 1.0 - (currentTime - 0.2) / 0.1 : 
                          (currentTime - 0.7) / 0.1;

        float upFactor = rayDir.y * 0.5 + 0.5;
        vec3 nightSkyGradient = mix(NIGHT_HORIZON, NIGHT_ZENITH, smoothstep(0.0, 1.0, upFactor));

        if (rayDir.y > 0.0) {

            vec3 stars = starField(rayDir, currentTime * 10.0);

            vec3 nebula = nebulaEffect(rayDir, currentTime * 5.0);

            vec3 nightSky = nightSkyGradient + stars + nebula;

            skyColor = mix(skyColor, nightSky, nightBlend);
        } else {

            skyColor = mix(skyColor, nightSkyGradient, nightBlend);
        }
    }

    fragColor = vec4(skyColor, 1.0);
}



