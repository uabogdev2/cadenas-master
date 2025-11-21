<?php

return [
    'levels' => [
        'seed_path' => env('LOCKGAME_LEVELS_SEED_PATH', storage_path('app/seeds/levels.json')),
        'export_path' => env('LOCKGAME_LEVELS_EXPORT_PATH', storage_path('app/exports/levels.json')),
    ],
    'battles' => [
        'waiting_ttl_minutes' => (int) env('LOCKGAME_BATTLE_WAITING_TTL', 5),
        'finished_ttl_minutes' => (int) env('LOCKGAME_BATTLE_FINISHED_TTL', 60),
    ],
];

