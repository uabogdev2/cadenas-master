<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\HasOne;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;

class User extends Authenticatable
{
    use HasFactory;
    use Notifiable;

    public const DEFAULT_POINTS = 500;
    public const DEFAULT_TROPHIES = 0;

    protected $table = 'users';

    protected $primaryKey = 'id';

    public $incrementing = false;

    protected $keyType = 'string';

    public const CREATED_AT = 'createdAt';
    public const UPDATED_AT = 'updatedAt';

    protected $fillable = [
        'id',
        'displayName',
        'email',
        'photoURL',
        'isAnonymous',
        'points',
        'completedLevels',
        'trophies',
        'createdAt',
        'updatedAt',
    ];

    protected $casts = [
        'isAnonymous' => 'boolean',
        'points' => 'integer',
        'completedLevels' => 'integer',
        'trophies' => 'integer',
        'createdAt' => 'datetime',
        'updatedAt' => 'datetime',
    ];

    public function stats(): HasOne
    {
        return $this->hasOne(UserStats::class, 'userId');
    }

    public function progress(): HasMany
    {
        return $this->hasMany(UserProgress::class, 'userId');
    }

    public function unlockedHints(): HasMany
    {
        return $this->hasMany(UnlockedHint::class, 'userId');
    }

    public function admin(): HasOne
    {
        return $this->hasOne(Admin::class, 'userId');
    }

    public function battlesAsPlayer1(): HasMany
    {
        return $this->hasMany(Battle::class, 'player1');
    }

    public function battlesAsPlayer2(): HasMany
    {
        return $this->hasMany(Battle::class, 'player2');
    }
}
