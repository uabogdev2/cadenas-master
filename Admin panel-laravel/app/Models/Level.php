<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Level extends Model
{
    use HasFactory;

    protected $table = 'levels';

    protected $fillable = [
        'name',
        'instruction',
        'code',
        'codeLength',
        'pointsReward',
        'isLocked',
        'timeLimit',
        'additionalHints',
        'hintCost',
        'createdAt',
        'updatedAt',
    ];

    protected $casts = [
        'isLocked' => 'boolean',
        'additionalHints' => 'array',
        'codeLength' => 'integer',
        'pointsReward' => 'integer',
        'timeLimit' => 'integer',
        'hintCost' => 'integer',
        'createdAt' => 'datetime',
        'updatedAt' => 'datetime',
    ];

    public const CREATED_AT = 'createdAt';
    public const UPDATED_AT = 'updatedAt';

    public function progress(): HasMany
    {
        return $this->hasMany(UserProgress::class, 'levelId');
    }

    public function unlockedHints(): HasMany
    {
        return $this->hasMany(UnlockedHint::class, 'levelId');
    }
}

