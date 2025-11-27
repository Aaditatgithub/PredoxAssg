# ---------------------------------------------
# Conversational Insight Generator Test Runner
# Sends all new transcripts to /analyze_call
# ---------------------------------------------

[Console]::InputEncoding  = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$endpoint = "http://127.0.0.1:8000/analyze_call"
$headers  = @{ "Content-Type" = "application/json; charset=utf-8" }

$initialDelaySeconds     = 10
$delayBetweenRequestsSec = 1

$transcripts = @(
@"
Agent: Good morning, main Sameer bol raha hoon, Zenith Finance se. Sir, aapka personal loan EMI due date 30th hai. Just a reminder. Customer: Haan, haan, I know. Tum log har month call karte ho. Basically reminder ke liye call kiya hai na? Agent: Yes, sir, just confirming. Koi issue toh nahi hai payment mein? Kyunki aapka previous month bhi thoda late hua tha. Customer: Woh last time thoda salary cycle ka issue ho gaya tha, yaar. Lekin don't worry this time. Definitely ho jayega. Like, 29th tak clear kar dunga. Agent: Achha, sir, 29th ka PTP main confirm karun? Agar late hua toh impact will be on your credit report, you know. Customer: Theek hai, theek hai. Book kar lo. Aur frequent calls mat karna, please. Agent: Understood, sir. Thank you for the assurance.
"@,
@"
Agent: Namaste. Main Rita, Apex Bank se. Aapka credit card minimum due next week hai. Customer: Haan, minimum due toh theek hai, par listen, maine ek transaction dispute kiya hua hai. I purchased something online, but product nahi mila. Agent: Ma'am, woh dispute process alag chalta hai. Aapka due amount toh clear karna padega to avoid late charges. Customer: Toh, basically, main poora amount pay karun jab dispute pending hai? That's not fair, yaar! Agent: Ma'am, aap undisputed amount pay kar dijiye. Late fees toh nahi lagni chahiye na? Customer: Hmm... Theek hai. Main half payment kar deti hoon aaj evening tak. Baaki dispute resolution ke baad. Agent: Okay, ma'am. Half payment note kar liya hai. Please ensure.
"@,
@"
Agent: Mr. Awasthi, aapka EMI 15 din se due hai. Reason kya hai? Humein immediate payment chahiye. Customer: Dekho, reason mat puchho, yaar. Thoda financial mismatch ho gaya hai suddenly. Woh company se payment late hua hai. Agent: Sir, kaun si company? Aur mismatch kitne din ka hai? Humein exact date chahiye. Otherwise, hum aapka account hard bucket mein shift kar denge. Customer: Hard bucket kya hota hai? Listen, main guarantee deta hoon, 15th tak. Paisa aa jayega pakka. Agent: Sir, 15th is too far. Aapko late payment fees aur interest dono lag rahe hain. Try to do it by Friday? Customer: Friday? Let me check... Achha, Friday ka promise karta hoon. No more calls till Friday, okay? Agent: PTP note ho gaya, sir.
"@,
@"
Agent: Ms. Pooja, aapka card overdue hai. 25 din ho gaye hain. Aapki taraf se koi response nahi aaya. Customer: Haan, main jaanti hoon. Financial situation not good hai. Mera rent bhi due hai. Agent: Ma'am, hum aapki situation understand karte hain, but payment mandatory hai. Aap minimum due toh clear kar sakti hain? Customer: Minimum due bhi tough hai right now. Like, I can only pay half of the minimum due. Would that be okay? Agent: Ma'am, that's not ideal, par agar aap woh amount aaj de den toh we can temporarily hold the escalation. Customer: Theek hai. Debit card se payment kar rahi hoon abhi.
"@,
@"
Agent: Mr. Singh, aapka loan 30 days se default mein hai. Hum final notice de rahe hain. Aap immediate action nahi le rahe. Customer: Listen, tum log roz call karke harass mat karo. Maine bola na, next month ki first week mein karunga! Agent: Sir, next month tak aapka account NPA ho jayega. You understand the implications? Aapka CIBIL score completely down ho jayega. Customer: Toh kya karun? Job nahi hai abhi. Agent: Sir, we need a formal letter for job loss. Otherwise, humein collection agency involve karni padegi. Give me a PTP date this week, or I initiate action. Customer: Uff... Monday ko chota amount karunga. Agent: Amount? Kitna? Customer: ₹5,000. Agent: Okay, ₹5,000 for Monday. We will monitor this closely.
"@,
@"
Agent: Mr. Khan, 75 days ho chuke hain. Aapka total outstanding ₹3.5 lakh hai. Hum aapko legal notice send kar rahe hain. Customer: Bhai, legal notice kiska? Faltu ki baatein mat karo. Maine already two months se interest pay kar diya hai! Agent: Sir, aapne interest pay kiya hai, principal zero hai. Aap poora amount ek saath kab denge? Customer: Poora toh nahi de paunga. Like, can we do a one-time settlement (OTS)? Agent: OTS ke liye, sir, aapko minimum 25% upfront dena hoga. Aap eligible hain? Customer: 25% toh try kar sakta hoon. Email pe scheme ki details bhej do. Agent: Details send kar dete hain. But first, you have to commit to an upfront amount today.
"@,
@"
Agent: Ma'am, this is the final call from our side. Aapka account 100 days se default mein hai. Customer: I told you already, meri saheli ka accident ho gaya tha. All my savings went there. I am in deep trouble. Agent: Ma'am, we need proof of your hardship. Otherwise, hum account closure aur recovery start kar denge. Customer: Yaar, help karo na thodi. Can you convert this credit card due into a small EMI loan? Agent: Ma'am, restructuring is a process. Aapko hardship form fill karna padega and hospital bills submit karne honge. Customer: Achha, email karo saare forms right now. I will try to submit by tomorrow. Agent: Okay, forms are being sent. Please prioritize this.
"@,
@"
Agent: Mr. Varma, aapke ghar pe field agent visit kar raha hai aaj sham tak. Aap cooperate nahi kar rahe. Customer: Kon hai woh field agent? Tell him to not come! Maine tum logon ko permission nahi di hai. You are harassing me! Agent: Sir, this is part of the recovery procedure. Aap payment kyon nahi kar rahe, simple answer do. Customer: Payment next week tak confirm hai! Main already HR se baat kar chuka hoon. Agent: Sir, next week nahi. Give me a date, a clear date. Otherwise, the field team will proceed. Customer: Monday ko subah tak RTGS kar dunga. Confirm! Agent: Theek hai, Monday morning ka PTP. We will recall the field team for now.
"@,
@"
Agent: Ma'am, aapne last week do baar PTP diya, aur dono baar fail ho gaya. This is not acceptable. Customer: Dekho, main try kar rahi hoon. Mera boss salary delay kar raha hai. What can I do? Agent: Ma'am, excuses mat dijiye. Your credit report is already damaged. Aapke paas koi security hai, ya koi asset jisse aap fund arrange kar saken? Customer: Asset? No way! I can give you partial payment, you know, ₹15,000, but guarantee do ki no more calls for one month. Agent: We can agree to hold calls for 7 days after payment. Customer: Deal. 7 days no calls. Done.
"@,
@"
Agent: Mr. Bansal, aapka loan 60 days past due hai. Hum legal process initiate kar rahe hain. Customer: Wait, wait! I want to settle. Kitna discount milega agar main lump sum de dun? Agent: Sir, settlement ke liye aapko eligibility check karni padegi. Aap total outstanding ka kitna % pay kar sakte hain? Customer: Like, main 50% de sakta hoon next 15 days mein. Agent: 50% is a good starting point. Hum aapki offer manager ko submit karte hain. But aapko processing fees upfront deni padegi. Customer: Processing fees kitni hogi? Tell me the total. Agent: Main aapko email pe detailed proposal bhejta hoon. Please check your email right now.
"@
)

Write-Host "Waiting $initialDelaySeconds seconds before sending first request..."
Start-Sleep -Seconds $initialDelaySeconds

Write-Host "Sending transcripts..."

$count = 1
foreach ($t in $transcripts) {
    Write-Host "`n--- Sending transcript $count ---"

    $payload = [pscustomobject]@{
        transcript = $t.Trim()
    }

    $body = $payload | ConvertTo-Json -Depth 10 -Compress

    $utf8    = New-Object System.Text.UTF8Encoding($false)
    $bodyRaw = $utf8.GetBytes($body)

    Write-Host "Request body:`n$body`n"

    try {
        $response = Invoke-WebRequest `
            -Method POST `
            -Uri $endpoint `
            -Headers $headers `
            -Body $bodyRaw `
            -ErrorAction Stop

        Write-Host "Response:" $response.Content
    }
    catch {
        Write-Host "Request failed: $($_.Exception.Message)"
        Write-Host "Server said (if any): $($_.ErrorDetails.Message)"
    }

    Start-Sleep -Seconds $delayBetweenRequestsSec
    $count++
}

Write-Host "`nDone."
