import Discord from "discord.js";
import http from "http";

import { readFileSync } from "fs";


let guild: Discord.Guild;
const channels: string[] = [];

const muted: { [id: string]: boolean } = {};

const get: any = [];

const client: Discord.Client = new Discord.Client();

const config = JSON.parse(readFileSync("./config.json", "utf8"));
const PORT: number = config.server.port;

client.login(config.discord.token);

client.on("ready", async () => {
  console.log("BOT: ON");
  console.log(config);

  guild = await client.guilds.fetch(config.discord.guild.toString(), false, true);
  guild.members.fetch();
  config.discord.mainChannels.forEach((channelID: number) =>
    channels.push(channelID.toString())
  );
});

client.on(
  "voiceStateUpdate",
  (oldState: Discord.VoiceState, newState: Discord.VoiceState) => {
    if (
      isInVoiceChannel(oldState) &&
      oldState.channelID != newState.channelID
    ) {
      const newMember = guild.members.cache.get(newState.id);
      
      if (newMember && isMutedByBot(newMember) && newState.serverMute)
        newMember.voice.setMute(false).then(() => {
          setMutedByBot(newMember, false);
        });
    }
  }
);

const isInVoiceChannel = (voiceState: Discord.VoiceState): boolean =>
  !!voiceState.channelID && channels.includes(voiceState.channelID);

const isMutedByBot = (member: Discord.GuildMember): boolean =>
  muted[member.id] == true;

const setMutedByBot = (
  member: Discord.GuildMember,
  set = true
): void => {
  muted[member.id] = set;
};

get["connect"] = async (params: any, ret: any) => {
  if (!guild) return;

  const { tag } = params;
  const found = [
    ...guild.members.cache.filter((val) => val.user.tag === tag).values(),
  ];

  if (!found.length) {
    return ret({
      answer: 1,
    });
  }

  ret({
    id: found[0].user.id,
    tag: found[0].user.tag,
  });
};

get["mute"] = async (
  params: { id: string; mute: boolean },
  ret: (result?: { success: boolean; error?: any } | undefined) => void
) => {
  const { id, mute } = params;

  console.log("mute",params);

  const member = await guild.members.fetch(id);
  if (!member) {
    return ret({
      success: false,
      error: "Member not found!",
    });
  }

  if (!isInVoiceChannel(member.voice)) {
    return ret({
      success: false,
      error: "Member not in voice channel!",
    });
  }

  if (member.voice.serverMute == !mute) {
    await member.voice.setMute(mute).catch((err) => {
      return ret({
        success: false,
        error: err,
      });
    });

    setMutedByBot(member, mute);
    ret({
      success: true,
    });
  }
};

http.createServer(async (req: http.IncomingMessage, res: http.ServerResponse) => {
  console.log(req.headers);
  const params = JSON.parse(req.headers.params as string);
  console.log(params);
  await get[req.headers.req as string](
    params,
    (ret?: { success: boolean; error?: any }) => {
      res.end(JSON.stringify(ret));
    }
  ).catch((err) => {
    res.end(JSON.stringify({ success: false, error: err }));
  });
})
  .listen(
    {
      port: PORT,
    },
    () => {
      console.log("HTTP: ON", { port: PORT });
    }
  );
