<?php

namespace App\Jobs;

use App\Services\BattleService;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;
use Illuminate\Support\Facades\Log;

class CleanupBattlesJob implements ShouldQueue
{
    use Dispatchable;
    use InteractsWithQueue;
    use Queueable;
    use SerializesModels;

    public function handle(BattleService $battleService): void
    {
        $result = $battleService->cleanupOldBattles();
        Log::info('CleanupBattlesJob executed', $result);
    }
}

