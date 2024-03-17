import java.util.Scanner;

public class LegkisebbLegnagyobb {
    public static void main(String[] args) {
        Scanner scanner = new Scanner(System.in);


        System.out.println("Add meg a tömb elemeit:");
        String input = scanner.nextLine();
        String[] elemekString = input.split(" ");
        int[] elemek = new int[elemekString.length];

        for (int i = 0; i < elemekString.length; i++) {
            elemek[i] = Integer.parseInt(elemekString[i]);
        }

        int legkisebb = elemek[0];
        int legnagyobb = elemek[0];
        for (int i = 1; i < elemek.length; i++) {
            if (elemek[i] < legkisebb) {
                legkisebb = elemek[i];
            }
            if (elemek[i] > legnagyobb) {
                legnagyobb = elemek[i];
            }
        }

        System.out.println("legkisebb elem: " + legkisebb);
        System.out.println("legnagyobb elem: " + legnagyobb);

        scanner.close();
    }
}
