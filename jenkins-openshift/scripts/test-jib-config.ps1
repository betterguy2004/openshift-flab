# Test Jib Configuration (PowerShell)
# This script validates that Jib is properly configured

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Jib Configuration Test" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

$ErrorActionPreference = "Stop"

# Check if we're in the right directory
if (-not (Test-Path "pom.xml")) {
    Write-Host "❌ Error: pom.xml not found" -ForegroundColor Red
    Write-Host "Please run this script from the spring-petclinic directory" -ForegroundColor Yellow
    exit 1
}

Write-Host "1. Checking Maven installation..." -ForegroundColor Yellow
try {
    $mvnVersion = mvn -version 2>&1 | Select-Object -First 1
    Write-Host "✓ Maven found: $mvnVersion" -ForegroundColor Green
} catch {
    Write-Host "❌ Maven not found. Please install Maven 3.9+" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "2. Checking Java version..." -ForegroundColor Yellow
try {
    $javaVersion = java -version 2>&1 | Select-Object -First 1
    Write-Host "✓ Java found: $javaVersion" -ForegroundColor Green
} catch {
    Write-Host "❌ Java not found. Please install Java 17+" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "3. Checking Jib plugin in pom.xml..." -ForegroundColor Yellow
$pomContent = Get-Content pom.xml -Raw
if ($pomContent -match "jib-maven-plugin") {
    if ($pomContent -match "<version>([\d.]+)</version>") {
        $jibVersion = $matches[1]
        Write-Host "✓ Jib plugin found: version $jibVersion" -ForegroundColor Green
    } else {
        Write-Host "✓ Jib plugin found" -ForegroundColor Green
    }
} else {
    Write-Host "❌ Jib plugin not found in pom.xml" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "4. Checking Nexus registry configuration..." -ForegroundColor Yellow
if ($pomContent -match "nexus.apps.s68") {
    Write-Host "✓ Nexus registry configured: nexus.apps.s68" -ForegroundColor Green
} else {
    Write-Host "❌ Nexus registry not configured" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "5. Checking environment variables..." -ForegroundColor Yellow
if (-not $env:NEXUS_USERNAME) {
    Write-Host "⚠ NEXUS_USERNAME not set (will use default: admin)" -ForegroundColor Yellow
    $env:NEXUS_USERNAME = "admin"
} else {
    Write-Host "✓ NEXUS_USERNAME: $env:NEXUS_USERNAME" -ForegroundColor Green
}

if (-not $env:NEXUS_PASSWORD) {
    Write-Host "⚠ NEXUS_PASSWORD not set (will use default: 123456789)" -ForegroundColor Yellow
    $env:NEXUS_PASSWORD = "123456789"
} else {
    Write-Host "✓ NEXUS_PASSWORD: ********" -ForegroundColor Green
}

Write-Host ""
Write-Host "6. Testing Nexus connectivity..." -ForegroundColor Yellow
try {
    $response = Invoke-WebRequest -Uri "http://nexus.apps.s68" -Method Head -TimeoutSec 5 -ErrorAction SilentlyContinue
    if ($response.StatusCode -in @(200, 302, 401)) {
        Write-Host "✓ Nexus registry is reachable" -ForegroundColor Green
    }
} catch {
    Write-Host "❌ Cannot reach Nexus registry at nexus.apps.s68" -ForegroundColor Red
    Write-Host "Please check network connectivity" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "7. Validating pom.xml..." -ForegroundColor Yellow
try {
    $validateOutput = mvn validate 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✓ pom.xml is valid" -ForegroundColor Green
    } else {
        Write-Host "❌ pom.xml validation failed" -ForegroundColor Red
        Write-Host $validateOutput
        exit 1
    }
} catch {
    Write-Host "❌ pom.xml validation failed" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "✅ All checks passed!" -ForegroundColor Green
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "You can now build and push the image with:" -ForegroundColor White
Write-Host "  mvn clean package jib:build" -ForegroundColor Yellow
Write-Host ""
Write-Host "Or test locally with Docker:" -ForegroundColor White
Write-Host "  mvn clean package jib:dockerBuild" -ForegroundColor Yellow
Write-Host ""
