-- Rephrase-in-place: select rough text anywhere (e.g. Slack compose box),
-- press the hotkey, and it's replaced with a rephrased version.
-- Uses a local Ollama model, so it's free and works fully offline.

require("hs.ipc")

-- Flip to false to make every SlackScribe hotkey global again (works in any
-- app, but risks colliding with that app's own shortcut for the same combo —
-- e.g. ⌘⇧R is "hard refresh" in most browsers). true = hotkeys only fire
-- while Slack is the frontmost app; in any other app, the keystroke passes
-- through untouched so that app's own shortcut still works normally.
local SLACK_ONLY = true

local OLLAMA_URL = "http://127.0.0.1:11434/api/generate"
local OLLAMA_MODEL = "qwen2.5:7b-instruct"

local SYSTEM_PROMPT =
  "You clean up rough, typo-ridden Slack messages. " ..
  "Fix ONLY spelling, grammar, and word order. Keep every fact, action, outcome, " ..
  "and word choice exactly as the user wrote it — do not substitute a word for " ..
  "one that changes its meaning (e.g. never turn 'correct'/'valid' into " ..
  "'wrong'/'incorrect', never turn 'don't know' into a confession, never add " ..
  "words like 'accidentally', 'again', 'mistake', or any detail that isn't " ..
  "already in the text). " ..
  "Keep it sounding like normal, casual, everyday spoken English — the way a " ..
  "person actually talks to a coworker on Slack. Simple words, short sentences, " ..
  "no corporate or stiff phrasing, no fancy vocabulary. " ..
  "Do not add greetings, sign-offs, explanations, or quotes around the text. " ..
  "Return ONLY the rewritten message, nothing else."

local SYSTEM_PROMPT_WITH_CONTEXT =
  "You help write Slack replies. You will be given the ORIGINAL MESSAGE the user " ..
  "is replying to, and the user's own ROUGH DRAFT reply. " ..
  "Rewrite the rough draft so it reads naturally as a reply to the original " ..
  "message, fixing ONLY spelling, grammar, and word order. Keep every fact, " ..
  "action, outcome, and word choice from the draft exactly as written — do not " ..
  "substitute a word for one that changes its meaning (e.g. never turn " ..
  "'correct'/'valid' into 'wrong'/'incorrect', never turn 'don't know' into a " ..
  "confession, never add words like 'accidentally', 'again', 'mistake', or any " ..
  "detail that isn't already in the draft). " ..
  "Keep it sounding like normal, casual, everyday spoken English — the way a " ..
  "person actually talks to a coworker on Slack. Simple words, short sentences, " ..
  "no corporate or stiff phrasing, no fancy vocabulary. " ..
  "Do not add greetings, sign-offs, explanations, or quotes. " ..
  "Return ONLY the rewritten reply, nothing else."

local SYSTEM_PROMPT_EXTRACT_POINTS =
  "List each distinct point in the given Slack message as a short numbered " ..
  "list. A distinct point is any comment, statement, question, reaction, or " ..
  "topic that could reasonably get its own individual response in a reply — " ..
  "including when the message was clearly sent as separate consecutive lines " ..
  "or messages by the same person on different topics. Keep each list item " ..
  "to one short phrase describing what that point is, not a full quote. " ..
  "Return ONLY the numbered list, nothing else — no preamble, no summary."

local SYSTEM_PROMPT_DRAFT =
  "You help someone reply on Slack to a message they received but aren't sure " ..
  "how to answer. You will be given that INCOMING MESSAGE. Write a short, " ..
  "complete, ready-to-send reply to it — the way a real person dashing off a " ..
  "quick, confident reply would. Commit to a specific, natural answer or " ..
  "reaction rather than hedging, staying vague, or deferring — a fully formed " ..
  "reply that occasionally needs a quick edit is more useful than a safe but " ..
  "wishy-washy one. Use your best judgment to fill in what's most plausible " ..
  "given the message, including taking a stance on questions, decisions, or " ..
  "opinions, and resolving ambiguous references to whatever they most " ..
  "plausibly mean. " ..
  "Sound like normal, casual, everyday spoken English — the way a person " ..
  "actually talks to a coworker on Slack, but keep it polished: casual does " ..
  "NOT mean slangy. Avoid slang/filler words like 'gotcha', 'yep', 'for " ..
  "sure', 'no biggie' — write the same relaxed sentence a professional would " ..
  "actually type to a colleague, not the loosest possible phrasing. Simple " ..
  "words, short sentences, no corporate or stiff phrasing, no greetings or " ..
  "sign-offs. " ..
  "KEEP IT SHORT — 1 to 3 short sentences (or two brief lines if there are " ..
  "genuinely two separate topics), matching the length of a real quick Slack " ..
  "reply, not an email. Weave your reactions to each point naturally into " ..
  "flowing sentences — never recap or list the points systematically " ..
  "('addressing each point...', '1. ... 2. ...'), and never mention or " ..
  "reference anything (like scheduling a demo) that the incoming message " ..
  "itself didn't actually raise, just because it was available in context. " ..
  "\n\n" ..
  "IMPORTANT — below the incoming message you will find a DISTINCT POINTS " ..
  "list: an already-extracted checklist of every separate point in that " ..
  "message. Treat this list as authoritative. Your reply MUST address every " ..
  "single point on that list — go down the list item by item and confirm " ..
  "each one is covered before finalizing. A reply that only addresses some " ..
  "of the listed points is WRONG, even if what it does address is " ..
  "well-written — silently dropping a listed point is a critical error, not " ..
  "a minor omission. Being short does NOT mean dropping a point: it means " ..
  "expressing every listed point briefly and naturally in as few words as " ..
  "possible, not padding one point with extra sentences while ignoring " ..
  "another. A 2-sentence reply that touches both points beats a 1-sentence " ..
  "reply that only touches one. " ..
  "\n\n" ..
  "EXAMPLE of the length and coverage you're aiming for — an incoming " ..
  "message with a reaction point AND a compliment/preference point, both " ..
  "covered in one short, natural sentence: DISTINCT POINTS were (1) other " ..
  "person composes elsewhere and has it auto-send, (2) they said they liked " ..
  "the first option best. A GOOD reply: 'Nice, that's a different workflow! " ..
  "Glad you liked the first one — that's actually the exact use case I " ..
  "built it for.' Notice it's one short sentence pair, yet still explicitly " ..
  "names both points — it does NOT drop the compliment just to stay brief. " ..
  "A compliment or stated preference (like 'I liked X') is exactly as " ..
  "mandatory to acknowledge as a question would be — never let it get " ..
  "silently absorbed into a generic 'thanks for sharing' instead of being " ..
  "named specifically. The same goes for a stated delay, apology, or excuse " ..
  "for not having done something yet (e.g. 'didn't get to it today', " ..
  "'sorry for the holdup') — it needs a short reassurance too ('No worries, " ..
  "'), but here the required edit is much smaller and stricter than for " ..
  "other points: first silently compose what you'd write if that delay/" ..
  "excuse line didn't exist at all, then ONLY prepend 'No worries, ' (or an " ..
  "equally short equivalent) to the front of that exact sentence. Do not " ..
  "rephrase, restructure, reorder, or add any other word anywhere else in " ..
  "the reply because of the delay/excuse — it earns exactly one short " ..
  "prefix, nothing more. EXAMPLE: if what you'd otherwise write is 'Got it, " ..
  "thanks for fitting it in after your call!', the correct final reply is " ..
  "'No worries, thanks for fitting it in after your call!' — identical " ..
  "except for those first two words.\n" ..
  "\n" ..
  "SPEAKER CHECK — the incoming message is written entirely by the OTHER " ..
  "PERSON, not you. Any 'I'/'my' statement inside the incoming message " ..
  "describes something THEY did, decided, or think — never restate their " ..
  "own stated action as if you did it yourself. Acknowledge it as theirs " ..
  "('thanks for doing that', 'got it, appreciate you handling that') " ..
  "rather than claiming it as your own action.\n" ..
  "\n" ..
  "The DISTINCT POINTS list is for your own planning only — never copy, " ..
  "repeat, or include any part of that numbered list itself in your output. " ..
  "Do not add quotes around the text or any explanation of what you wrote. " ..
  "Return ONLY the final natural reply text a person would actually send, " ..
  "nothing else — no list, no labels, no meta-commentary."

local SYSTEM_PROMPT_DRAFT_WITH_CONTEXT =
  "You help someone reply on Slack to a message they received but aren't sure " ..
  "how to answer. You will be given EARLIER CONTEXT and an INCOMING MESSAGE. " ..
  "Write a short, complete, ready-to-send reply — the way a real person " ..
  "dashing off a quick, confident reply would. Commit to a specific, natural " ..
  "answer or reaction rather than hedging, staying vague, or deferring — a " ..
  "fully formed reply that occasionally needs a quick edit is more useful " ..
  "than a safe but wishy-washy one. Use your best judgment to fill in what's " ..
  "most plausible given the context, including taking a stance on questions, " ..
  "decisions, or opinions, and resolving ambiguous references to whatever " ..
  "they most plausibly mean. " ..
  "\n\n" ..
  "CRITICAL — whose words are whose: the EARLIER CONTEXT was written BY THE " ..
  "USER THEMSELVES (the person you're drafting this reply for) — it is their " ..
  "own prior message, their own words, their own project/tool/idea/decision if " ..
  "it mentions one. The user already knows everything in it; it is not new " ..
  "information to them. The INCOMING MESSAGE is the OTHER PERSON's reply to " ..
  "that — anything new, different, or additional in it belongs to the other " ..
  "person, not the user. " ..
  "Never write the user reacting to their own earlier message as if it were " ..
  "new to them. Never have the user say they'll 'check out', 'look into', " ..
  "'explore', 'try', or 'compare' anything that the earlier context shows the " ..
  "user already made, said, or knows — this applies even when it's phrased as " ..
  "checking/comparing 'both' or 'both approaches' together with the other " ..
  "person's thing, since that still implies the user needs to go research " ..
  "their own work. The user does not need to check out, look into, explore, " ..
  "try, or compare their own earlier context ever, under any phrasing. Only " ..
  "react to what the OTHER PERSON actually added or said in the incoming " ..
  "message — comment on it, appreciate it, ask about it, agree with it, but " ..
  "don't fold it into something the user still needs to go evaluate. If " ..
  "you're unsure who a detail belongs to, default to treating it as the other " ..
  "person's, not the user's. This is the one place you should NOT guess — " ..
  "ownership confusion here is always wrong, not just occasionally wrong. " ..
  "This also means: if the earlier context already offered, proposed, or " ..
  "said something (e.g. 'happy to do a demo'), and your reply wants to bring " ..
  "that up, treat it as something ALREADY ON THE TABLE, not a new idea just " ..
  "occurring to the user — build on it ('let's do that demo, then') rather " ..
  "than re-suggesting it as if for the first time.\n" ..
  "\n" ..
  "Also read the ENTIRE incoming message before drafting: don't ask a " ..
  "question whose answer is already stated elsewhere in that same incoming " ..
  "message — that's a sign you reacted to one part without registering " ..
  "another part that already answered it.\n" ..
  "\n" ..
  "Sound like normal, casual, everyday spoken English — the way a person " ..
  "actually talks to a coworker on Slack, but keep it polished: casual does " ..
  "NOT mean slangy. Avoid slang/filler words like 'gotcha', 'yep', 'for " ..
  "sure', 'no biggie' — write the same relaxed sentence a professional would " ..
  "actually type to a colleague, not the loosest possible phrasing. Simple " ..
  "words, short sentences, no corporate or stiff phrasing, no greetings or " ..
  "sign-offs. " ..
  "KEEP IT SHORT — 1 to 3 short sentences (or two brief lines if there are " ..
  "genuinely two separate topics), matching the length of a real quick Slack " ..
  "reply, not an email. Weave your reactions to each point naturally into " ..
  "flowing sentences — never recap or list the points systematically " ..
  "('addressing each point...', '1. ... 2. ...'), and never mention or " ..
  "reference anything (like scheduling a demo) that the incoming message " ..
  "itself didn't actually raise, just because it was available in context. " ..
  "\n\n" ..
  "IMPORTANT — below the incoming message you will find a DISTINCT POINTS " ..
  "list: an already-extracted checklist of every separate point in that " ..
  "message. Treat this list as authoritative. Your reply MUST address every " ..
  "single point on that list — go down the list item by item and confirm " ..
  "each one is covered before finalizing. A reply that only addresses some " ..
  "of the listed points is WRONG, even if what it does address is " ..
  "well-written — silently dropping a listed point is a critical error, not " ..
  "a minor omission. Being short does NOT mean dropping a point: it means " ..
  "expressing every listed point briefly and naturally in as few words as " ..
  "possible, not padding one point with extra sentences while ignoring " ..
  "another. A 2-sentence reply that touches both points beats a 1-sentence " ..
  "reply that only touches one. " ..
  "\n\n" ..
  "EXAMPLE of the length and coverage you're aiming for — an incoming " ..
  "message with a reaction point AND a compliment/preference point, both " ..
  "covered in one short, natural sentence: DISTINCT POINTS were (1) other " ..
  "person composes elsewhere and has it auto-send, (2) they said they liked " ..
  "the first option best. A GOOD reply: 'Nice, that's a different workflow! " ..
  "Glad you liked the first one — that's actually the exact use case I " ..
  "built it for.' Notice it's one short sentence pair, yet still explicitly " ..
  "names both points — it does NOT drop the compliment just to stay brief. " ..
  "A compliment or stated preference (like 'I liked X') is exactly as " ..
  "mandatory to acknowledge as a question would be — never let it get " ..
  "silently absorbed into a generic 'thanks for sharing' instead of being " ..
  "named specifically. The same goes for a stated delay, apology, or excuse " ..
  "for not having done something yet (e.g. 'didn't get to it today', " ..
  "'sorry for the holdup') — it needs a short reassurance too ('No worries, " ..
  "'), but here the required edit is much smaller and stricter than for " ..
  "other points: first silently compose what you'd write if that delay/" ..
  "excuse line didn't exist at all, then ONLY prepend 'No worries, ' (or an " ..
  "equally short equivalent) to the front of that exact sentence. Do not " ..
  "rephrase, restructure, reorder, or add any other word anywhere else in " ..
  "the reply because of the delay/excuse — it earns exactly one short " ..
  "prefix, nothing more. EXAMPLE: if what you'd otherwise write is 'Got it, " ..
  "thanks for fitting it in after your call!', the correct final reply is " ..
  "'No worries, thanks for fitting it in after your call!' — identical " ..
  "except for those first two words.\n" ..
  "\n" ..
  "The DISTINCT POINTS list is for your own planning only — never copy, " ..
  "repeat, or include any part of that numbered list itself in your output. " ..
  "Do not add quotes around the text or any explanation of what you wrote. " ..
  "Return ONLY the final natural reply text a person would actually send, " ..
  "nothing else — no list, no labels, no meta-commentary."

local SYSTEM_PROMPT_TONE = {
  casual =
    "Rewrite the given Slack message to sound MORE CASUAL and relaxed than it " ..
    "currently is — like texting a close coworker. Simpler words, more " ..
    "contractions, more relaxed rhythm. " ..
    "Do NOT change any fact, action, outcome, or piece of information in the " ..
    "message — only adjust tone and word choice, nothing else. " ..
    "Do not add greetings, sign-offs, quotes, or explanations. " ..
    "Return ONLY the rewritten message, nothing else.",

  professional =
    "Rewrite the given Slack message to sound MORE PROFESSIONAL and polished " ..
    "than it currently is — clearer wording, fewer casual contractions — while " ..
    "still reading like a normal person, not stiff corporate-speak. " ..
    "Do NOT change any fact, action, outcome, or piece of information in the " ..
    "message — only adjust tone and word choice, nothing else. " ..
    "Do not add greetings, sign-offs, quotes, or explanations. " ..
    "Return ONLY the rewritten message, nothing else.",
}

local SYSTEM_PROMPT_SUMMARIZE =
  "You summarize a block of Slack messages so the reader can quickly catch up " ..
  "without rereading each one. The text may include senders' names and " ..
  "timestamps mixed in with the message content — use them to note who said " ..
  "what if it's relevant, but don't treat a name or timestamp itself as " ..
  "something that was said. " ..
  "Write a short, factual summary covering: the main point(s), any decisions " ..
  "made, any open questions, and any action items or next steps mentioned. " ..
  "Use a few short sentences or bullet points — whichever reads clearer for " ..
  "this content. " ..
  "OPEN QUESTIONS CHECK — scan for every question mark in the messages; if a " ..
  "question is never followed by an answer later in the same text, it is a " ..
  "live open question and must be listed, even if it seems minor. Only omit a " ..
  "question if the messages clearly answer it afterward. " ..
  "Do NOT add opinions, interpretations, or information that isn't actually " ..
  "in the messages. " ..
  "Do not add greetings, sign-offs, or any explanation of what you're doing. " ..
  "Return ONLY the summary, nothing else."

-- Captured via the context hotkey; nil until the user captures something.
-- Auto-expires after CONTEXT_TTL seconds so a forgotten capture from an
-- earlier message can never silently bleed into a later, unrelated reply.
local capturedContext = nil
local contextExpiryTimer = nil
local CONTEXT_TTL = 45

local function clearContext()
  capturedContext = nil
  if contextExpiryTimer then
    contextExpiryTimer:stop()
    contextExpiryTimer = nil
  end
end

local function setContext(text)
  capturedContext = text
  if contextExpiryTimer then
    contextExpiryTimer:stop()
  end
  contextExpiryTimer = hs.timer.doAfter(CONTEXT_TTL, function()
    capturedContext = nil
    contextExpiryTimer = nil
  end)
end

-- Rare model glitch safety net: occasionally the model drops all the spaces
-- from a run of words, producing something like "canparalleleditingget
-- messy". No real English word gets anywhere close to this length, so an
-- unbroken run this long is a reliable, false-positive-free signal that
-- the response is corrupted -- worth one silent automatic retry rather
-- than showing garbled text to the user.
local function looksGarbled(text)
  for word in text:gmatch("%a+") do
    if #word >= 22 then
      return true
    end
  end
  return false
end

local function rephraseText(input, callback, isRetry)
  if input == nil or input:gsub("%s", "") == "" then
    hs.alert.show("Nothing selected to rephrase")
    return
  end

  local systemPrompt = SYSTEM_PROMPT
  local promptBody = input

  if capturedContext ~= nil and capturedContext:gsub("%s", "") ~= "" then
    systemPrompt = SYSTEM_PROMPT_WITH_CONTEXT
    promptBody = "ORIGINAL MESSAGE:\n" .. capturedContext ..
      "\n\nROUGH DRAFT REPLY:\n" .. input
  end

  local payload = hs.json.encode({
    model = OLLAMA_MODEL,
    system = systemPrompt,
    prompt = promptBody,
    stream = false,
    -- Keep the model resident in memory for longer than Ollama's default
    -- (~5 min) so intermittent use during a work session doesn't keep
    -- paying the full model-reload cost on every first hotkey press.
    keep_alive = "30m",
    options = { temperature = 0.1 },
  })

  if not isRetry then
    hs.alert.show("Rephrasing...", 1)
  end

  hs.http.asyncPost(OLLAMA_URL, payload, { ["Content-Type"] = "application/json" },
    function(status, body, headers)
      if status ~= 200 then
        hs.alert.show("Rephrase failed (status " .. tostring(status) .. "). Is Ollama running?")
        return
      end
      local ok, decoded = pcall(hs.json.decode, body)
      if not ok or not decoded or not decoded.response then
        hs.alert.show("Rephrase failed: bad response from Ollama")
        return
      end
      local result = decoded.response:gsub("^%s+", ""):gsub("%s+$", "")
      if looksGarbled(result) and not isRetry then
        rephraseText(input, callback, true)
        return
      end
      callback(result)
    end)
end

local function adjustToneText(input, direction, callback, isRetry)
  if input == nil or input:gsub("%s", "") == "" then
    hs.alert.show("Select the text you want to adjust first")
    return
  end

  local payload = hs.json.encode({
    model = OLLAMA_MODEL,
    system = SYSTEM_PROMPT_TONE[direction],
    prompt = input,
    stream = false,
    -- Keep the model resident in memory for longer than Ollama's default
    -- (~5 min) so intermittent use during a work session doesn't keep
    -- paying the full model-reload cost on every first hotkey press.
    keep_alive = "30m",
    options = { temperature = 0.2 },
  })

  if not isRetry then
    hs.alert.show(
      direction == "casual" and "Making it more casual..." or "Making it more professional...",
      1
    )
  end

  hs.http.asyncPost(OLLAMA_URL, payload, { ["Content-Type"] = "application/json" },
    function(status, body, headers)
      if status ~= 200 then
        hs.alert.show("Tone adjust failed (status " .. tostring(status) .. "). Is Ollama running?")
        return
      end
      local ok, decoded = pcall(hs.json.decode, body)
      if not ok or not decoded or not decoded.response then
        hs.alert.show("Tone adjust failed: bad response from Ollama")
        return
      end
      local result = decoded.response:gsub("^%s+", ""):gsub("%s+$", "")
      if looksGarbled(result) and not isRetry then
        adjustToneText(input, direction, callback, true)
        return
      end
      callback(result)
    end)
end

local function summarizeText(input, callback, isRetry)
  if input == nil or input:gsub("%s", "") == "" then
    hs.alert.show("Nothing selected to summarize")
    return
  end

  local payload = hs.json.encode({
    model = OLLAMA_MODEL,
    system = SYSTEM_PROMPT_SUMMARIZE,
    prompt = input,
    stream = false,
    -- Keep the model resident in memory for longer than Ollama's default
    -- (~5 min) so intermittent use during a work session doesn't keep
    -- paying the full model-reload cost on every first hotkey press.
    keep_alive = "30m",
    options = { temperature = 0.2 },
  })

  if not isRetry then
    hs.alert.show("Summarizing...", 1)
  end

  hs.http.asyncPost(OLLAMA_URL, payload, { ["Content-Type"] = "application/json" },
    function(status, body, headers)
      if status ~= 200 then
        hs.alert.show("Summarize failed (status " .. tostring(status) .. "). Is Ollama running?")
        return
      end
      local ok, decoded = pcall(hs.json.decode, body)
      if not ok or not decoded or not decoded.response then
        hs.alert.show("Summarize failed: bad response from Ollama")
        return
      end
      local result = decoded.response:gsub("^%s+", ""):gsub("%s+$", "")
      if looksGarbled(result) and not isRetry then
        summarizeText(input, callback, true)
        return
      end
      callback(result)
    end)
end

-- Runs a single Ollama /api/generate call and hands the trimmed text response
-- to callback(result), or shows an alert and returns nothing on failure.
local function ollamaGenerate(systemPrompt, promptBody, temperature, failureLabel, callback, numPredict, isRetry)
  local payload = hs.json.encode({
    model = OLLAMA_MODEL,
    system = systemPrompt,
    prompt = promptBody,
    stream = false,
    -- Keep the model resident in memory for longer than Ollama's default
    -- (~5 min) so intermittent use during a work session doesn't keep
    -- paying the full model-reload cost on every first hotkey press.
    keep_alive = "30m",
    -- num_predict caps how many tokens the model can generate. Both the
    -- points list and the draft reply are meant to be short by design, so
    -- this is a speed ceiling, not a behavior change — it only kicks in if
    -- something would have run on far longer than intended anyway.
    options = { temperature = temperature, num_predict = numPredict or 150 },
  })

  hs.http.asyncPost(OLLAMA_URL, payload, { ["Content-Type"] = "application/json" },
    function(status, body, headers)
      if status ~= 200 then
        hs.alert.show(failureLabel .. " (status " .. tostring(status) .. "). Is Ollama running?")
        return
      end
      local ok, decoded = pcall(hs.json.decode, body)
      if not ok or not decoded or not decoded.response then
        hs.alert.show(failureLabel .. ": bad response from Ollama")
        return
      end
      local result = decoded.response:gsub("^%s+", ""):gsub("%s+$", "")
      if looksGarbled(result) and not isRetry then
        ollamaGenerate(systemPrompt, promptBody, temperature, failureLabel, callback, numPredict, true)
        return
      end
      callback(result)
    end)
end

-- Defensive safety net: if the model ever echoes back its planning checklist
-- (e.g. "Addressing each point: 1. ... 2. ...") instead of just the natural
-- reply, strip it out. A real Slack reply from this tool never legitimately
-- contains a multi-line numbered list, so cutting at the first sign of one
-- is safe and never removes real content.
local function stripLeakedChecklist(text)
  local lines = {}
  for line in (text .. "\n"):gmatch("(.-)\n") do
    table.insert(lines, line)
  end

  local cutAt = nil
  for i, line in ipairs(lines) do
    if line:match("^%s*[Aa]ddressing each point") then
      cutAt = i
      break
    end
    if line:match("^%s*%d+%.%s") and lines[i + 1] and lines[i + 1]:match("^%s*%d+%.%s") then
      cutAt = i
      break
    end
  end

  if cutAt == nil then
    return text
  end

  local kept = {}
  for i = 1, cutAt - 1 do
    table.insert(kept, lines[i])
  end
  return table.concat(kept, "\n"):gsub("%s+$", "")
end

local function draftReplyText(incomingMessage, callback)
  if incomingMessage == nil or incomingMessage:gsub("%s", "") == "" then
    hs.alert.show("Nothing selected to draft a reply to")
    return
  end

  hs.alert.show("Drafting a reply...", 1)

  -- Stage 1: extract the distinct points as an explicit written checklist,
  -- rather than trusting the final draft call to silently count and
  -- remember them all in one pass.
  ollamaGenerate(SYSTEM_PROMPT_EXTRACT_POINTS, incomingMessage, 0.1, "Draft failed",
    function(pointsList)
      local systemPrompt = SYSTEM_PROMPT_DRAFT
      local promptBody = "INCOMING MESSAGE:\n" .. incomingMessage ..
        "\n\nDISTINCT POINTS:\n" .. pointsList

      if capturedContext ~= nil and capturedContext:gsub("%s", "") ~= "" then
        systemPrompt = SYSTEM_PROMPT_DRAFT_WITH_CONTEXT
        promptBody = "EARLIER CONTEXT:\n" .. capturedContext .. "\n\n" .. promptBody
      end

      -- Stage 2: draft the reply, using that checklist as the authoritative
      -- point list to address.
      ollamaGenerate(systemPrompt, promptBody, 0.15, "Draft failed", function(result)
        callback(stripLeakedChecklist(result))
      end, 120)
    end, 100)
end

-- Copies the current selection and reads it back, retrying a few times since
-- some apps (Slack/Electron especially) are slower to write to the clipboard.
-- Detects success via hs.pasteboard.changeCount() (an OS-level counter that
-- bumps on every clipboard write) rather than comparing text content — if the
-- text you're copying happens to be identical to what was already on the
-- clipboard (e.g. re-copying a rephrase right after it was pasted, before the
-- old clipboard gets restored), a content comparison would wrongly conclude
-- nothing was copied.
local function copySelection(onSuccess, onFailure)
  local savedClipboard = hs.pasteboard.getContents()
  local beforeCount = hs.pasteboard.changeCount()

  -- Wait a beat before sending the synthetic ⌘C. The hotkey fires the instant
  -- you press ⌘⇧C/⌘⇧D/etc, but your physical Shift/Cmd keys can still be
  -- technically held for a few ms after — sending ⌘C immediately risks it
  -- merging with the still-held Shift and coming out as ⌘⇧C again, which
  -- Slack won't treat as copy. Letting the real keys release first avoids that.
  hs.timer.doAfter(0.08, function()
    hs.eventtap.keyStroke({"cmd"}, "c", 0)

    local attempts = 0
    local function check()
      attempts = attempts + 1
      local afterCount = hs.pasteboard.changeCount()

      if afterCount ~= beforeCount then
        onSuccess(hs.pasteboard.getContents(), savedClipboard)
      elseif attempts < 10 then
        hs.timer.doAfter(0.15, check)
      else
        onFailure()
      end
    end

    hs.timer.doAfter(0.15, check)
  end)
end

-- Pastes newText over the current selection, then re-selects exactly what was
-- just pasted (so it stays highlighted as a visual "this just changed" cue),
-- shows a confirmation alert, and restores the clipboard to what it held
-- before we started.
local function pasteAndHighlight(newText, savedClipboard, doneLabel)
  hs.pasteboard.setContents(newText)
  hs.eventtap.keyStroke({"cmd"}, "v", 0)

  hs.timer.doAfter(0.1, function()
    local ok, charCount = pcall(utf8.len, newText)
    if not ok or charCount == nil then
      charCount = #newText
    end
    -- The cursor sits at the end of the pasted text right after ⌘V. Move it
    -- back to the start first (no selection yet), then select forward with
    -- shift+Right — the highlight grows left-to-right, which reads more
    -- naturally than growing right-to-left from the end.
    for _ = 1, charCount do
      hs.eventtap.keyStroke({}, "left", 0)
    end
    for _ = 1, charCount do
      hs.eventtap.keyStroke({"shift"}, "right", 0)
    end
    hs.alert.show(doneLabel, 1)
  end)

  hs.timer.doAfter(0.4, function()
    if savedClipboard ~= nil then
      hs.pasteboard.setContents(savedClipboard)
    end
  end)
end

local function rephraseSelection()
  copySelection(
    function(selected, savedClipboard)
      rephraseText(selected, function(rephrased)
        pasteAndHighlight(rephrased, savedClipboard, "Rephrased ✓")
        -- Context is one-shot: clear it so it doesn't leak into your next reply
        clearContext()
      end)
    end,
    function()
      hs.alert.show("Select some text first, then press ⌘⇧R")
    end
  )
end

local function captureContext()
  copySelection(
    function(selected, savedClipboard)
      setContext(selected)
      hs.pasteboard.setContents(savedClipboard)
      hs.alert.show(
        "Context captured (expires in " .. CONTEXT_TTL .. "s) — now ⌘⇧R your draft, " ..
        "or select their reply and press ⌘⇧D",
        3
      )
    end,
    function()
      hs.alert.show("Select the message you're replying to first, then press ⌘⇧G")
    end
  )
end

local function draftReply()
  copySelection(
    function(selected, savedClipboard)
      draftReplyText(selected, function(drafted)
        -- Leave the drafted reply on the clipboard (don't restore) — the
        -- selection was on the incoming message, not the compose box, so we
        -- can't safely auto-paste. The user pastes it themselves.
        hs.pasteboard.setContents(drafted)
        hs.alert.show("Reply drafted — click the message box and press ⌘V to paste", 3)
        -- Context is one-shot: clear it so it doesn't leak into your next reply
        clearContext()
      end)
    end,
    function()
      hs.alert.show("Select the message you want to reply to first, then press ⌘⇧D")
    end
  )
end

local function summarizeSelection()
  copySelection(
    function(selected, savedClipboard)
      summarizeText(selected, function(summary)
        -- This is for reading, not sending — leave it on the clipboard (in
        -- case you want to paste it somewhere afterward) and show it in a
        -- proper dialog you can actually read, not a quick fading alert.
        hs.pasteboard.setContents(summary)
        hs.dialog.blockAlert("Summary", summary, "OK")
      end)
    end,
    function()
      hs.alert.show("Select the messages you want summarized first, then press ⌘⇧S")
    end
  )
end

local function adjustTone(direction)
  copySelection(
    function(selected, savedClipboard)
      adjustToneText(selected, direction, function(result)
        local label = direction == "casual" and "More casual ✓" or "More professional ✓"
        pasteAndHighlight(result, savedClipboard, label)
      end)
    end,
    function()
      hs.alert.show("Select the text you want to adjust first")
    end
  )
end

-- When SLACK_ONLY is true, a bound combo only runs its SlackScribe action
-- while Slack is frontmost. In any other app, we re-post the identical
-- keystroke so that app's own shortcut fires normally — e.g. a browser still
-- hard-refreshes on ⌘⇧R instead of SlackScribe silently swallowing it.
local function isSlackFrontmost()
  local app = hs.application.frontmostApplication()
  return app ~= nil and app:name() == "Slack"
end

local function bindHotkey(modifiers, key, handler)
  hs.hotkey.bind(modifiers, key, function()
    if (not SLACK_ONLY) or isSlackFrontmost() then
      handler()
    else
      hs.eventtap.keyStroke(modifiers, key, 0)
    end
  end)
end

-- Hotkey: Cmd+Shift+X — manually clear any captured context
bindHotkey({"cmd", "shift"}, "X", function()
  clearContext()
  hs.alert.show("Context cleared")
end)

-- Hotkey: Cmd+Shift+G — capture the message you're replying to (context)
-- (moved off ⌘⇧C because another app on this Mac — likely a screenshot/
-- recording tool — also claims that combo as a global hotkey, which silently
-- broke our synthetic copy)
bindHotkey({"cmd", "shift"}, "G", captureContext)

-- Hotkey: Cmd+Shift+R — rephrase your reply (uses captured context if present)
bindHotkey({"cmd", "shift"}, "R", rephraseSelection)

-- Hotkey: Cmd+Shift+D — draft a reply from scratch to a selected incoming message
bindHotkey({"cmd", "shift"}, "D", draftReply)

-- Hotkey: Cmd+Shift+Down — dial the selected text more casual
bindHotkey({"cmd", "shift"}, "down", function() adjustTone("casual") end)

-- Hotkey: Cmd+Shift+Up — dial the selected text more professional
bindHotkey({"cmd", "shift"}, "up", function() adjustTone("professional") end)

-- Hotkey: Cmd+Shift+S — summarize several selected messages
bindHotkey({"cmd", "shift"}, "S", summarizeSelection)

hs.alert.show(
  "Rephrase hotkeys loaded (⌘⇧R rephrase, ⌘⇧G capture, ⌘⇧D draft, " ..
  "⌘⇧↑ more professional, ⌘⇧↓ more casual, ⌘⇧S summarize, ⌘⇧X clear)" ..
  (SLACK_ONLY and " — Slack-only" or " — global")
)
