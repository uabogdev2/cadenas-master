<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class GameConfig extends Model
{
    /**
     * The attributes that are mass assignable.
     *
     * @var array<int, string>
     */
    protected $fillable = [
        'trophies_win',
        'trophies_loss',
        'trophies_draw',
        'game_timer',
        'question_timer',
        'min_version_android',
        'min_version_ios',
        'force_update',
        'maintenance_mode',
    ];

    /**
     * The attributes that should be cast.
     *
     * @var array<string, string>
     */
    protected $casts = [
        'force_update' => 'boolean',
        'maintenance_mode' => 'boolean',
        'trophies_win' => 'integer',
        'trophies_loss' => 'integer',
        'trophies_draw' => 'integer',
        'game_timer' => 'integer',
        'question_timer' => 'integer',
    ];
}
