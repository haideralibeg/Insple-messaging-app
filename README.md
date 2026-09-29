# Talkr 
This messaging app is all about bringing a fun, nostalgic twist to everyday communication. It lets users chat in a personalized way, with customizable themes inspired by different eras. Ex: 80s mode or a Gen Z mode. The goal is to keep this app lightweight, and focus on giving people a playful, creative way to connect with their friends and family.

Group Members 
- Haider Beg
- Binod Chhantyal
- Jonathan Gilreath
- Grayson Turner
- Tyler Snow

## Communication modes

**Nostalgic** brings a 90s/early 2000s desktop messenger feel: navy title bars,
beveled gray controls, a buddy list, square avatars, and a white, chronological
transcript with screen names and timestamps. A multiline composer and text
emoticons (`:)`, `;)`, `:D`, `<3`) keep the flow simple. Original two-note sent
and received chimes can be disabled in the conversation; they respect Silent
Mode and do not play when loading message history.

**Gen Z** is the expressive direction: a dark, vibrant interface with colorful
message bubbles, emojis, memes, GIFs, and reactions. The current implementation
provides the dark interface and text messaging; GIFs, memes, and reactions are
future features.

Switch modes from the top bar in the inbox or conversation. Both modes use the
same Firebase conversation, and switching preserves your unsent draft. The
selected mode is saved to the user profile; the sound setting is device-local.

### Manual verification

- Switch modes with an unsent draft; confirm the draft and transcript remain.
- Open a conversation in Nostalgic mode; confirm history loads without a chime.
- Exchange new messages between two accounts; check distinct sent/received chimes.
- Turn sounds off, then test with the phone's Silent Mode enabled.
- Sign out and back in; confirm the selected mode is restored.
- Check a long message, multiline draft, large text size, and an empty buddy list.
