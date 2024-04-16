public class TakarekSzamla extends NormalSzamla {
    private double kamatRata;

    public TakarekSzamla(String tulajdonosNeve, double kamatRata) {
        super(tulajdonosNeve);
        this.kamatRata = kamatRata;
    }

    public void hozzaadKamat() {
        double kamat = getEgyenleg() * kamatRata / 100;
        betesz(kamat);
    }

    @Override
    public boolean equals(Object o) {
        if (this == o) return true;
        if (!(o instanceof TakarekSzamla)) return false;
        if (!super.equals(o)) return false;
        TakarekSzamla that = (TakarekSzamla) o;
        return Double.compare(that.kamatRata, kamatRata) == 0;
    }
}
