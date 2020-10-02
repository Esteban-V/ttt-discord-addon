const Discord = require('discord.js');
const http = require('http');
const fs = require('fs');


const config = require('./config.json');

const PORT = config.server.port;

let guild, deadsChannel;
let channels = [];

let muted = {};

let get = [];

const client = new Discord.Client({sync:true});

client.login(config.discord.token);

client.on('ready', async () => {
	console.log('BOT: ON');
	
	guild = client.guilds.cache.get(config.discord.guild);
	config.discord.mainChannels.forEach(channelID => channels.push(channelID));
});


client.on('voiceStateUpdate', (oldState, newState) => {
	if (isInVoiceChannel(oldState) && oldState.channelID != newState.channelID) {
		if (isMutedByBot(newState) && newState.serverMute) newMember.setMute(false).then(()=>{
			setMutedByBot(newMember, false);
		});
	}
});

isInVoiceChannel = (voiceState) => voiceState.channelID && channels.includes(voiceState.channelID);
isMutedByBot = (member) => muted[member.id] == true;
setMutedByBot = (member, set) => muted[member.id] = set;

get['connect'] = (params, ret) => {
	let tag = params.tag;

	let found = guild.members.cache.filter(val => val.user.tag.match(new RegExp('.*' + tag + '.*')));
	if (found.length > 1) {
		ret({
			answer: 1
		});
	}else if (found.length < 1) {
		ret({
			answer: 0
		});
	}else {
		ret({
			tag: found[0].user.tag,
			id: found[0].id
		});
	}
};

get['mute'] = (params,ret) => {
	const id = params.id;
	const mute = params.mute;
	
	if (typeof id !== 'string' || typeof mute !== 'boolean') {
		ret();
		return;
	}
	
	const member = guild.members.cache.get(id);

	if(member) {
		if (member.voice.channelID && isInVoiceChannel(member.voice)) {
			if (!member.voice.serverMute && mute) {
				member.voice.setMute(true).then(()=>{
					setMutedByBot(member);
					ret({
						success: true
					});
				}).catch((err)=>{
					ret({
						success: false,
						error: err
					});
				});
			}
			if (member.serverMute && !mute) {
				member.setMute(false).then(()=>{
					setMutedByBot(member, false);
					ret({
						success: true
					});
				}).catch((err)=>{
					ret({
						success: false,
						error: err
					});
				});
			}
		} else {
			ret();
		}

	}else {
		ret({
			success: false,
			err: 'Member not found!'
		});
	}

}


http.createServer((req,res)=>{
	if (typeof req.headers.params === 'string' && typeof req.headers.req === 'string' && typeof get[req.headers.req] === 'function') {
		try {
			const params = JSON.parse(req.headers.params);
			get[req.headers.req](params, function(ret){
				res.end(JSON.stringify(ret));
			});
		}catch(e) {
			res.end('Invalid JSON');
		}
	}else
		res.end();
}).listen({
	port: PORT
},()=>{
	console.log('HTTP: ON')
});
