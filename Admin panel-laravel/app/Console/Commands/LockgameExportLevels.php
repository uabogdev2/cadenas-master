<?php

namespace App\Console\Commands;

use App\Services\LevelService;
use Illuminate\Console\Command;

class LockgameExportLevels extends Command
{
    protected $signature = 'lockgame:export-levels {--path= : Chemin de sortie personnalisé}';

    protected $description = 'Exporte la table levels au format data/levels.json.';

    public function handle(LevelService $levelService): int
    {
        $path = $levelService->exportToPath($this->option('path'));
        $this->info("Niveaux exportés dans {$path}");

        return self::SUCCESS;
    }
}

