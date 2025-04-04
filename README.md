# Minecraft Vanilla Skybox

[![](https://dcbadge.limes.pink/api/server/INVITE?style=flat)](https://discord.gg/avSH2JTfef)

my discord server : [https://discord.gg/avSH2JTfef](https://discord.gg/avSH2JTfef)


Only supports 1.21.5 and up (plus 25w10a and up for snapshots)!

An implementation of procedurally generated skyboxes in vanilla Minecraft without requiring a sun.png texture file.

This is a fork of [Balint Csala's vanilla skybox template pack](https://github.com/balintcsala/minecraft-vanilla-skybox). If you find this implementation helpful, consider donating to the original author:

|                                                             |                                                                                                 |
| ----------------------------------------------------------- | ----------------------------------------------------------------------------------------------- |
| [![kofi](./images/kofi.png)](https://ko-fi.com/balintcsala) | [![paypal](./images/paypal.png)](https://www.paypal.com/donate/?hosted_button_id=9CJYN7ETGZJPS) |

You're free to use this pack forever in return for credit and links to both this repository and the original repository on any distribution site. If these terms don't work for you, contact the original author on Discord (@balintcsala) or through GitHub.

![alt text](/images/image.png)
![alt text](/images/image2.png)
<video controls src="https://cdn.discordapp.com/attachments/1357079104880382182/1357083723169796096/2025-04-02_22-03-15.mp4?ex=67ef92f5&is=67ee4175&hm=0ec3f1a28c17c537d612eb277f77048e348ffcf1c2d098519aa4ecd71f4d9fb2&" title="
"></video>

<video controls src="https://cdn.discordapp.com/attachments/1357079104880382182/1357393960988835901/2025-04-03_18-38-19.mp4?ex=67f00b23&is=67eeb9a3&hm=84b19ae0077e3e81310e26dc1bb27c2903530b5bc1be0d13004cd269c7cc5f37&" title=""></video>



## Key Changes from Original Implementation

This fork modifies the original implementation to:

- Generate skyboxes procedurally through shader code instead of relying on the sun.png texture file

## Customization

Customization is done directly in the shaders rather than through image files:

- Modify the skybox generation algorithm in `assets/minecraft/shaders/core/position_tex_color.fsh`

## Other customizations

- The shader removes fog by default because it might clash with the skybox. To revert this, delete `assets/minecraft/shaders/include/fog.glsl`.
- The shader removes the horizon of the game (only appears at sunset and gives the lower edge of the sky an orangeish hue). If you want to revert this, delete `assets/minecraft/shaders/core/position_color.vsh` and the same but with `.fsh`


## Limitations

- Requires shader knowledge to customize effectively
- Most likely not compatible with graphics mods like Sodium, IRIS, OptiFine
- Procedural generation may have a slight performance impact on lower-end devices

## Original Project

For the texture-based implementation, see the original project at [balintcsala/minecraft-vanilla-skybox](https://github.com/balintcsala/minecraft-vanilla-skybox).
