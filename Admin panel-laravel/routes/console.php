<?php

use App\Jobs\CleanupBattlesJob;
use Illuminate\Foundation\Inspiring;
use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\Schedule;

Artisan::command('inspire', function () {
    $this->comment(Inspiring::quote());
})->purpose('Display an inspiring quote');

Schedule::job(new CleanupBattlesJob())->everyFiveMinutes();
Schedule::command('lockgame:export-levels')->daily();
