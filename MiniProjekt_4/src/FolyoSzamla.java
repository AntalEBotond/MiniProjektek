public class FolyoSzamla extends NormalSzamla {
    private int tranzakciokSzama;
    private static final int INGYENES_TRANZAKCIOK_SZAMA = 10;
    private static final double TRANZAKCIO_DIJ = 100.0;

    public FolyoSzamla(String tulajdonosNeve) {
        super(tulajdonosNeve);
    }

    @Override
    public void betesz(double osszeg) {
        super.betesz(osszeg);
        tranzakciokSzama++;
    }

    @Override
    public void kivesz(double osszeg) throws InsufficientFundsException {
        super.kivesz(osszeg);
        tranzakciokSzama++;
        if (tranzakciokSzama > INGYENES_TRANZAKCIOK_SZAMA) {
            levonKoltseg();
        }
    }

    private void levonKoltseg() {
        double dij = TRANZAKCIO_DIJ * (tranzakciokSzama - INGYENES_TRANZAKCIOK_SZAMA);
        try {
            super.kivesz(dij);
        } catch (InsufficientFundsException e) {
            System.out.println("Nem sikerült levonni a tranzakciós díjat: " + e.getMessage());
        }
        tranzakciokSzama = 0;
    }

    @Override
    public boolean equals(Object o) {
        if (this == o) return true;
        if (!(o instanceof FolyoSzamla)) return false;
        if (!super.equals(o)) return false;
        FolyoSzamla that = (FolyoSzamla) o;
        return tranzakciokSzama == that.tranzakciokSzama;
    }
}
