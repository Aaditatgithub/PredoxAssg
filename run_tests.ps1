# ---------------------------------------------
# Conversational Insight Generator Test Runner
# Sends all 10 sample transcripts to /analyze_call
# With initial delay + UTF-8 body encoding + basic error handling
# ---------------------------------------------

# Force console encodings to UTF-8 (helps with display/logging)
[Console]::InputEncoding  = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$endpoint = "http://127.0.0.1:8000/analyze_call"
$headers  = @{ "Content-Type" = "application/json; charset=utf-8" }

# Config
$initialDelaySeconds     = 10   # Wait this long before the FIRST request
$delayBetweenRequestsSec = 1    # Wait between each transcript

$transcripts = @(
@"
Agent: Hello, main Maya bol rahi hoon, Apex Finance se. Kya main Mr. Sharma se baat kar sakti hoon? Customer: Haan, main bol raha hoon. Kya hua? Agent: Sir, aapka personal loan ka EMI due date 3rd of next month hai. Just calling for a friendly reminder. Aapka payment ready hai na? Customer: Oh, okay. Haan, salary aa jayegi tab tak. I will definitely pay it on time, don't worry. Agent: Thank you, sir. Payment time pe ho jaye toh aapka credit score bhi maintain rahega. Have a good day!
"@,
@"
Agent: Namaste. Main Priyanka, City Bank credit card department se. Aapka minimum due ₹8,500 hai, jo 10th ko due ho raha hai. Customer: Ji, pata hai. I think main poora amount nahi de paunga, but minimum toh kar dunga. Agent: Sir, pura payment karna best hai, par minimum due must hai to avoid late fees. Koi issue toh nahi hai payment mein? Customer: Nahi, no issue. I’ll clear it by the 8th. Agent: Great! Thank you for the confirmation.
"@,
@"
Agent: Hello Mr. Verma, main Aman bol raha hoon. Aapka personal loan EMI 7 days se overdue hai. Aapne payment kyun nahi kiya? Customer: Dekhiye, thoda emergency aa gaya tha. Mera bonus expected hai next week. Agent: Sir, aapko pata hai ki is par penalty lag rahi hai. Aap exact date bataiye, kab tak confirm payment ho jayega? Customer: Wednesday ko pakka kar dunga. Promise to Pay (PTP) le lo Wednesday ka. Agent: Okay, main aapka PTP book kar raha hoon next Wednesday ke liye. Please ensure payment is done to stop further charges.
"@,
@"
Agent: Good afternoon, Ms. Jain. Aapke credit card ka minimum due 15 din se pending hai. Customer: Oh, I forgot completely. Office mein kaam zyada tha. Agent: Ma'am, aapka total outstanding ab ₹45,000 ho gaya hai, including late fees. Aap aaj hi ₹8,500 ka minimum payment immediate kar dijiye. Customer: Aaj toh nahi ho payega. Sunday ko final karungi. Agent: Sunday is fine, ma'am, but late fees apply ho chuki hain. Please make sure.
"@,
@"
Agent: Mr. Khan, aapka loan account N-P-A hone ke risk par hai. 25 days ho gaye hain. Ye serious matter hai. Customer: Main out of station hoon, server issue hai mere bank mein. Agent: Sir, aap online transfer kar sakte hain, ya phir family member se karwa dijiye. Account status kharab ho raha hai. Customer: Thik hai, thik hai. Main next 3 hours mein try karta hoon. Agent: Sir, try nahi, I need a guarantee. Kya main 3 hours mein confirmation call karun? Customer: Haan, call kar lo.
"@,
@"
Agent: Mr. Reddy, main Legal Department se baat kar raha hoon. Aapka loan 60 days se default mein hai. Humari team aapki location par visit karne ki planning kar rahi hai. Customer: Please, visit mat bhejo. Meri job chali gayi hai. I need time! Agent: Sir, time humne bahut diya hai. Aap kitna amount abhi immediately de sakte hain? Customer: Abhi main only ₹10,000 de sakta hoon. Baaki next month. Agent: Okay, ₹10,000 ka token payment kar dijiye. Hum aapki file temporary hold par rakhenge.
"@,
@"
Agent: Ma'am, aapka account write-off hone ki verge par hai. 90 days ho gaye hain. Aapka total due ₹1.5 lakh hai. Customer: Main itna paisa nahi de sakti. Please settlement option do. Agent: Settlement ke liye aapko pehle minimum 30% upfront dena hoga. Kya aap eligible hain? Customer: Mujhe details mail kar do. Main check karti hoon. Agent: Main aapko final warning de raha hoon. Agar aapne action nahi liya toh legal notice jayega.
"@,
@"
Agent: Mr. Singh, aapka case external agency ko assign ho chuka hai. Hum final discussion ke liye call kar rahe hain. Aapki property par charge hai. Customer: No, no, personal loan par koi charge nahi hai. Stop threatening! Agent: Sir, as per the loan agreement, hum action le sakte hain. Aap aaj ₹25,000 transfer kijiye for account regularization. Customer: I'll talk to my lawyer. Agent: That's your right, sir, but payment is mandatory.
"@,
@"
Agent: Hello, Mr. Kumar. 60 days outstanding. What is the payment plan? Customer: Maine aapko pehle hi bataya tha, ek transaction fraud tha. Jab tak woh resolve nahi hoga, main payment nahi karunga. Agent: Sir, dispute department separate hai. Aapka due amount legal hai. You must pay the undisputed amount first. Customer: No, first resolve the dispute! Agent: Sir, both processes run parallel. Please pay the minimum due today.
"@,
@"
Agent: Ms. Pooja, hum aapko 75 days se call kar rahe hain. Aap cooperate nahi kar rahe. Customer: Meri mother hospital mein hain. Serious financial hardship hai. I am requesting a restructuring of the loan. Agent: Ma'am, we understand the situation. Lekin restructuring ke liye aapko hardship application fill karni hogi aur last 3 months ka bank statement dena hoga. Customer: Okay, send me the form.
"@
)

Write-Host "Waiting $initialDelaySeconds seconds before sending first request..." -ForegroundColor Yellow
Start-Sleep -Seconds $initialDelaySeconds

Write-Host "Sending transcripts..." -ForegroundColor Cyan

$count = 1
foreach ($t in $transcripts) {
    Write-Host "`n--- Sending transcript $count ---"

    # Build the JSON payload
    $payload = [pscustomobject]@{
        transcript = $t.Trim()
    }

    $body = $payload | ConvertTo-Json -Depth 10 -Compress

    # Convert JSON string to raw UTF-8 bytes (no BOM)
    $utf8    = New-Object System.Text.UTF8Encoding($false)
    $bodyRaw = $utf8.GetBytes($body)

    # Debug: see the JSON being sent
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
        Write-Host "Request failed: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "Server said (if any): $($_.ErrorDetails.Message)" -ForegroundColor DarkYellow
    }

    Start-Sleep -Seconds $delayBetweenRequestsSec
    $count++
}

Write-Host "`nDone."
